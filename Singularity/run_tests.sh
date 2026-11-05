#!/bin/bash
#
# run_tests.sh - automate the feasible tests from Singularity/test_sing_images.md
#
# WHERE TO RUN THIS
#   From the *Terminal* pane of a running OOD RStudio Server session (so that
#   the script inherits the environment set up by /etc/rstudio/rsession.sh).
#   Launch the session as the test document specifies:
#
#     Number of CPUs to allocate: 3
#     Start RStudio with a new user state directory: checked
#
#   Then:  bash Singularity/run_tests.sh
#
# RUN THIS FROM AN EMPTY HOME DIRECTORY
#   The tests verify that the R packages, the r-reticulate virtualenv and the
#   r-conda environment are all created from scratch. A pre-existing package
#   library or python environment is therefore reported as a FAILURE, not a
#   pass: it means the run is not testing what it claims to.
#
# WHAT IS NOT AUTOMATED (reported as SKIP, verify by hand)
#   - TensorFlow / GPU tests (RELEASE <= 3.18, requires a GPU node)
#   - anything that requires the RStudio IDE itself (Session -> Restart R,
#     the Copilot/Posit Assistant panes). Each R test below runs in a fresh
#     R process, which is equivalent to the "restart R" steps in the document.
#   - spacy / spacyr (RELEASE <= 3.19): enable with --spacy
#
set -u -o pipefail

readonly PROG=${0##*/}

#-----------------------------------------------------------------------------
# options
#-----------------------------------------------------------------------------

# NB: do not name this "GROUPS" -- that is a bash special array (the caller's
# group IDs) and assignments to it are silently ignored.
ALL_GROUPS="env fs slurm r venv conda pip"
RUN_GROUPS=""
SKIP_GROUPS=""
QUICK=0
DO_SPACY=0
EXPECTED_CPUS=""
RELEASE_OVERRIDE=""
LOG=""
TEST_TIMEOUT=${TEST_TIMEOUT:-3600}

usage() {
  cat <<EOF
Usage: ${PROG} [options]

Test groups (default: all of them)
  env     environment set by rsession.sh (R_LIBS_USER, OMP_NUM_THREADS, reticulate paths, ...)
  fs      filesystem / user state directory (~/.local/share/rstudio) and bind mounts
  slurm   Slurm query commands work; job-submission commands are stubbed out
  r       R package repo is pinned to a date, install goes to R_LIBS_USER, availableCores()
  venv    reticulate virtualenv "r-reticulate" (numpy/pandas/scipy) -- downloads from PyPI
  conda   reticulate miniconda env "r-conda" (scipy/pandas)         -- downloads a lot
  pip     a plain "pip install" lands in PYTHONUSERBASE (RELEASE <= 3.19 only)

Options
  --only GROUPS     comma/space separated list of groups to run
  --skip GROUPS     comma/space separated list of groups to skip
  --quick           same as --skip venv,conda,pip (no large network installs)
  --spacy           also run the spacy/spacyr test (RELEASE <= 3.19, slow)
  --cpus N          CPUs the session was allocated (default: detected from cpu affinity)
  --release N       Bioconductor minor release, e.g. 23 (default: parsed from R_LIBS_USER)
  --log FILE        write full command output here (default: a file under \$TMPDIR)
  --list            list the test groups and exit
  -h, --help        this message

Environment
  TEST_TIMEOUT      seconds allowed per R/pip step (default: ${TEST_TIMEOUT})

Exit status is 0 only if no test FAILed.
EOF
}

normalize_groups() { printf '%s' "$1" | tr ',' ' '; }

while [ $# -gt 0 ]; do
  case $1 in
    --only)    RUN_GROUPS=$(normalize_groups "${2-}"); shift 2 ;;
    --skip)    SKIP_GROUPS=$(normalize_groups "${2-}"); shift 2 ;;
    --quick)   QUICK=1; shift ;;
    --spacy)   DO_SPACY=1; shift ;;
    --cpus)    EXPECTED_CPUS=${2-}; shift 2 ;;
    --release) RELEASE_OVERRIDE=${2-}; shift 2 ;;
    --log)     LOG=${2-}; shift 2 ;;
    --list)    printf '%s\n' ${ALL_GROUPS}; exit 0 ;;
    -h|--help) usage; exit 0 ;;
    *) printf '%s: unknown option: %s\n' "${PROG}" "$1" >&2; usage >&2; exit 2 ;;
  esac
done

[ ${QUICK} -eq 1 ] && SKIP_GROUPS="${SKIP_GROUPS} venv conda pip"
[ -n "${RUN_GROUPS}" ] || RUN_GROUPS=${ALL_GROUPS}

group_enabled() {
  local want skip
  for want in ${RUN_GROUPS}; do
    if [ "${want}" = "$1" ]; then
      for skip in ${SKIP_GROUPS}; do
        [ "${skip}" = "$1" ] && return 1
      done
      return 0
    fi
  done
  return 1
}

#-----------------------------------------------------------------------------
# scratch space, logging, result bookkeeping
#-----------------------------------------------------------------------------

TMPD=$(mktemp -d "${TMPDIR:-/tmp}/run_tests.XXXXXX") || exit 1
trap 'rm -rf "${TMPD}"' EXIT

[ -n "${LOG}" ] || LOG="${TMPDIR:-/tmp}/run_tests.$(date +%Y%m%d-%H%M%S).log"
: >"${LOG}" || { printf '%s: cannot write %s\n' "${PROG}" "${LOG}" >&2; exit 1; }

if [ -t 1 ]; then
  C_PASS=$'\033[32m'; C_FAIL=$'\033[31m'; C_SKIP=$'\033[33m'; C_OFF=$'\033[0m'; C_HDR=$'\033[1m'
else
  C_PASS=""; C_FAIL=""; C_SKIP=""; C_OFF=""; C_HDR=""
fi

n_pass=0 n_fail=0 n_skip=0
failed_tests=""
skipped_tests=""

log() { printf '%s\n' "$*" >>"${LOG}"; }

log_block() { # log_block <title> ; stdin is the block content
  { printf '\n===== %s =====\n' "$1"; cat; } >>"${LOG}"
}

record() { # record <PASS|FAIL|SKIP> <name> [detail]
  local status=$1 name=$2 detail=${3-}
  case ${status} in
    PASS) n_pass=$((n_pass + 1)); printf '  %sPASS%s  %s' "${C_PASS}" "${C_OFF}" "${name}" ;;
    FAIL) n_fail=$((n_fail + 1)); failed_tests="${failed_tests}${name}"$'\n'
          printf '  %sFAIL%s  %s' "${C_FAIL}" "${C_OFF}" "${name}" ;;
    SKIP) n_skip=$((n_skip + 1)); skipped_tests="${skipped_tests}${name}"$'\n'
          printf '  %sSKIP%s  %s' "${C_SKIP}" "${C_OFF}" "${name}" ;;
    *)    printf '  ????  %s' "${name}" ;;
  esac
  [ -n "${detail}" ] && printf ' -- %s' "${detail}"
  printf '\n'
  log "${status}  ${name}${detail:+ -- ${detail}}"
}

pass() { record PASS "$1" "${2-}"; }
fail() { record FAIL "$1" "${2-}"; }
skip() { record SKIP "$1" "${2-}"; }

check_eq() { # check_eq <name> <expected> <actual>
  if [ "$2" = "$3" ]; then pass "$1" "$3"; else fail "$1" "expected '$2', got '$3'"; fi
}

check_nonempty() { # check_nonempty <name> <value>
  if [ -n "$2" ]; then pass "$1" "$2"; else fail "$1" "unset or empty"; fi
}

header() { printf '\n%s%s%s\n' "${C_HDR}" "$1" "${C_OFF}"; log ""; log "########## $1"; }

run_cmd() { # run under a timeout when available
  if command -v timeout >/dev/null 2>&1; then
    timeout "${TEST_TIMEOUT}" "$@"
  else
    "$@"
  fi
}

#-----------------------------------------------------------------------------
# R helpers
#
# Each R test script prints tab-separated "RESULT<TAB>PASS|FAIL|SKIP<TAB>name
# <TAB>detail" lines, which are folded into the summary here. Running each
# script as a separate process is the automated equivalent of the document's
# "restart R (Session -> Restart R)" steps.
#-----------------------------------------------------------------------------

# Preamble injected at the top of every generated R script.
readonly R_PREAMBLE='
res <- function(status, name, detail = "") {
  detail <- gsub("[\t\r\n]+", " ", paste(detail, collapse = " "))
  cat(sprintf("RESULT\t%s\t%s\t%s\n", status, name, detail))
  flush(stdout())
}
ok   <- function(cond, name, detail = "") res(if (isTRUE(cond)) "PASS" else "FAIL", name, detail)
try_ok <- function(expr, name, detail = "") {
  out <- tryCatch({ expr; TRUE }, error = function(e) conditionMessage(e))
  if (isTRUE(out)) res("PASS", name, detail) else res("FAIL", name, out)
}
'

run_r() { # run_r <label> <r-script-file>
  local label=$1 file=$2 out rc tag status name detail perr last

  # Rscript evaluates a file incrementally rather than via source(), so a syntax
  # error part way down only surfaces after the statements above it have already
  # run -- which makes it look like a runtime failure. Parse the whole file up
  # front instead. (A top-level "if (x)\n foo()\nelse\n bar()" is the usual
  # culprit: at top level the if-statement ends at the newline and the bare
  # "else" is a syntax error. Use "} else {".)
  if ! perr=$(Rscript -e "invisible(parse('${file}'))" 2>&1); then
    fail "${label}: R syntax error" "${perr##*$'\n'}"
    return 1
  fi

  out=$(run_cmd Rscript "${file}" 2>&1); rc=$?
  printf '%s\n' "${out}" | log_block "${label} (Rscript ${file##*/}, exit ${rc})"
  while IFS=$'\t' read -r tag status name detail; do
    [ "${tag}" = "RESULT" ] || continue
    record "${status}" "${name}" "${detail}"
  done < <(printf '%s\n' "${out}")
  if [ ${rc} -ne 0 ]; then
    # surface the last real line of output -- usually the R error message
    last=$(printf '%s\n' "${out}" | grep -v '^RESULT' | sed '/^[[:space:]]*$/d' | tail -1)
    fail "${label}: R exited ${rc}" "${last:+${last} -- }see ${LOG}"
    return 1
  fi
  return 0
}

r_file() { # r_file <basename> ; writes preamble, returns path on stdout
  local f="${TMPD}/$1.R"
  printf '%s\n' "${R_PREAMBLE}" >"${f}"
  printf '%s' "${f}"
}

#-----------------------------------------------------------------------------
# context detection
#-----------------------------------------------------------------------------

# The app launches the image with "singularity exec --containall", which implies
# --cleanenv, so SINGULARITY_CONTAINER / APPTAINER_CONTAINER are usually NOT set
# inside the session. Detect the container from the filesystem first and fall
# back to whichever of the environment variables happens to survive.
in_container=0
container_desc="<not in a container>"
if [ -e /.singularity.d ] || [ -e /singularity ] || [ -e /.dockerenv ] \
   || [ -n "${SINGULARITY_CONTAINER:-}" ] || [ -n "${APPTAINER_CONTAINER:-}" ] \
   || [ -n "${SINGULARITY_NAME:-}" ] || [ -n "${APPTAINER_NAME:-}" ] \
   || [ -n "${SINGULARITY_ENVIRONMENT:-}" ] || [ -n "${APPTAINER_ENVIRONMENT:-}" ]; then
  in_container=1
  container_desc=${SINGULARITY_CONTAINER:-${APPTAINER_CONTAINER:-${SINGULARITY_NAME:-${APPTAINER_NAME:-}}}}
  [ -n "${container_desc}" ] || container_desc="detected via /.singularity.d (no SINGULARITY_* in the environment; --containall implies --cleanenv)"
fi

image_tag=""
image_version=""
if [ -n "${R_LIBS_USER:-}" ]; then
  image_tag=${R_LIBS_USER%/}
  image_tag=${image_tag##*/}
fi
case ${image_tag} in
  RELEASE_3_*) image_version=${image_tag#RELEASE_3_} ;;
esac
[ -n "${RELEASE_OVERRIDE}" ] && image_version=${RELEASE_OVERRIDE}
case ${image_version} in
  ''|*[!0-9]*) image_version="" ;;
esac

# CPUs the job was actually given (cgroup / affinity), used to check OMP_NUM_THREADS
detect_cpus() {
  local list n=0 range lo hi
  list=$(awk '/^Cpus_allowed_list:/ {print $2}' /proc/self/status 2>/dev/null)
  [ -n "${list}" ] || { nproc 2>/dev/null || echo ""; return; }
  local IFS=','
  for range in ${list}; do
    case ${range} in
      *-*) lo=${range%-*}; hi=${range#*-}; n=$((n + hi - lo + 1)) ;;
      *)   n=$((n + 1)) ;;
    esac
  done
  printf '%s' "${n}"
}
[ -n "${EXPECTED_CPUS}" ] || EXPECTED_CPUS=$(detect_cpus)

version_ge() { # version_ge N -> true if image_version >= N (false if version unknown)
  [ -n "${image_version}" ] && [ "${image_version}" -ge "$1" ]
}
version_le() {
  [ -n "${image_version}" ] && [ "${image_version}" -le "$1" ]
}

#-----------------------------------------------------------------------------
# group: env
#-----------------------------------------------------------------------------

test_env() {
  header "Environment (rsession.sh)"

  if [ ${in_container} -eq 1 ]; then
    pass "env/in-container" "${container_desc}"
  else
    fail "env/in-container" "not running inside the Singularity container -- run this from the RStudio Server Terminal pane"
  fi

  check_nonempty "env/R_LIBS_USER-set" "${R_LIBS_USER:-}"
  case ${R_LIBS_USER:-} in
    */R/ifxrstudio/RELEASE_3_*) pass "env/R_LIBS_USER-layout" "${R_LIBS_USER}" ;;
    *) fail "env/R_LIBS_USER-layout" "expected ~/R/ifxrstudio/RELEASE_3_<n>, got '${R_LIBS_USER:-}'" ;;
  esac
  if [ -n "${R_LIBS_USER:-}" ] && [ -d "${R_LIBS_USER}" ] && [ -w "${R_LIBS_USER}" ]; then
    pass "env/R_LIBS_USER-writable"
  else
    fail "env/R_LIBS_USER-writable" "${R_LIBS_USER:-<unset>} missing or not writable"
  fi

  if [ -n "${image_version}" ]; then
    pass "env/release-detected" "RELEASE_3_${image_version}"
  else
    skip "env/release-detected" "could not parse release from R_LIBS_USER; use --release N"
  fi

  # OMP_NUM_THREADS is exported by rsession.sh from SLURM_JOB_CPUS_PER_NODE and
  # must match the CPUs the job was allocated (test doc: 3 CPUs -> 3).
  if [ -n "${EXPECTED_CPUS}" ]; then
    check_eq "env/OMP_NUM_THREADS" "${EXPECTED_CPUS}" "${OMP_NUM_THREADS:-<unset>}"
  else
    check_nonempty "env/OMP_NUM_THREADS" "${OMP_NUM_THREADS:-}"
  fi
  check_eq "env/MKL_THREADING_LAYER" "GNU" "${MKL_THREADING_LAYER:-<unset>}"
  check_eq "env/PIP_NO_CACHE_DIR" "off" "${PIP_NO_CACHE_DIR:-<unset>}"
  check_eq "env/RETICULATE_MINICONDA_ENABLED" "FALSE" "${RETICULATE_MINICONDA_ENABLED:-<unset>}"

  # reticulate paths live under R_LIBS_USER from RELEASE 3.22 on, so that they
  # do not collide with ~/.local and ~/.virtualenvs
  if version_ge 22; then
    check_eq "env/RETICULATE_MINICONDA_PATH" "${R_LIBS_USER:-}/reticulate-miniconda" \
             "${RETICULATE_MINICONDA_PATH:-<unset>}"
    check_eq "env/RETICULATE_VIRTUALENV_ROOT" "${R_LIBS_USER:-}/reticulate-virtualenvs" \
             "${RETICULATE_VIRTUALENV_ROOT:-<unset>}"
  else
    skip "env/RETICULATE_MINICONDA_PATH" "RELEASE <= 3.21 uses ~/.local"
    skip "env/RETICULATE_VIRTUALENV_ROOT" "RELEASE <= 3.21 uses ~/.virtualenvs"
  fi

  if version_le 19; then
    check_eq "env/PYTHONUSERBASE" "${R_LIBS_USER:-}/python-user-base" "${PYTHONUSERBASE:-<unset>}"
    case ":${PATH}:" in
      *":${PYTHONUSERBASE:-__unset__}/bin:"*) pass "env/python-user-base-on-PATH" ;;
      *) fail "env/python-user-base-on-PATH" "${PYTHONUSERBASE:-<unset>}/bin not in PATH" ;;
    esac
  else
    skip "env/PYTHONUSERBASE" "RELEASE >= 3.20 does not use a pip user base"
  fi

  # texlive is prepended to PATH by rsession.sh
  if command -v pdflatex >/dev/null 2>&1; then
    pass "env/pdflatex-on-PATH" "$(command -v pdflatex)"
  else
    fail "env/pdflatex-on-PATH" "pdflatex not found"
  fi

  # Renviron.site was replaced with the minimal rocker version: the Bioconductor
  # variables must be gone.
  if [ -z "${BIOCPARALLEL_WORKER_NUMBER:-}" ]; then
    pass "env/Renviron.site-overridden" "BIOCPARALLEL_WORKER_NUMBER unset"
  else
    fail "env/Renviron.site-overridden" "BIOCPARALLEL_WORKER_NUMBER=${BIOCPARALLEL_WORKER_NUMBER}"
  fi

  local f; f=$(r_file env)
  cat >>"${f}" <<'EOF'
libs <- .libPaths()
rlu  <- normalizePath(Sys.getenv("R_LIBS_USER"), mustWork = FALSE)
ok(length(libs) > 0 && normalizePath(libs[1], mustWork = FALSE) == rlu,
   "env/R-libPaths-first", paste(libs, collapse = ":"))
ok(Sys.getenv("OMP_NUM_THREADS") != "" , "env/R-sees-OMP_NUM_THREADS",
   Sys.getenv("OMP_NUM_THREADS"))
# Renviron.site must not reintroduce the Bioconductor settings
ok(Sys.getenv("BIOCPARALLEL_WORKER_NUMBER") == "" &&
   Sys.getenv("BIOCPARALLEL_NUM_WORKERS") == "",
   "env/R-no-BiocParallel-vars",
   paste0("BIOCPARALLEL_WORKER_NUMBER='", Sys.getenv("BIOCPARALLEL_WORKER_NUMBER"),
          "' BIOCPARALLEL_NUM_WORKERS='", Sys.getenv("BIOCPARALLEL_NUM_WORKERS"), "'"))
res("PASS", "env/R-version", paste(R.version$major, R.version$minor, sep = "."))
EOF
  run_r "env" "${f}"
}

#-----------------------------------------------------------------------------
# group: fs
#-----------------------------------------------------------------------------

is_mountpoint() { # is_mountpoint <path>
  awk -v p="$1" '$5 == p { found = 1 } END { exit !found }' /proc/self/mountinfo 2>/dev/null
}

test_fs() {
  header "Filesystem"

  local state_dir="${HOME}/.local/share/rstudio"

  if command -v findmnt >/dev/null 2>&1; then
    findmnt -o TARGET,FSTYPE,SOURCE -R "$(dirname "${HOME}")" 2>&1 | log_block "findmnt $(dirname "${HOME}")"
  fi
  awk '{print $5, $9, $10}' /proc/self/mountinfo 2>/dev/null | log_block "/proc/self/mountinfo (target fstype source)"

  # Both states are legitimate -- the form has a checkbox -- so report which one
  # is in effect rather than failing.
  if [ -d "${state_dir}" ] && is_mountpoint "${state_dir}"; then
    pass "fs/user-state-dir-is-mount" "${state_dir} is a mountpoint (\"new user state directory\" checked)"
  elif [ -d "${state_dir}" ]; then
    skip "fs/user-state-dir-is-mount" "${state_dir} is NOT a mountpoint -- expected if the \"new user state directory\" box was unchecked, a FAILURE if it was checked"
  else
    fail "fs/user-state-dir-is-mount" "${state_dir} does not exist"
  fi

  if [ -w "${state_dir}" ]; then
    pass "fs/user-state-dir-writable"
  else
    fail "fs/user-state-dir-writable" "${state_dir} not writable"
  fi

  # scratch mounts created by "singularity exec --scratch /run,/scratch,/tmp,..."
  local d
  for d in /tmp /run /var/lib/rstudio-server; do
    if [ -w "${d}" ]; then pass "fs/writable${d}"; else fail "fs/writable${d}" "not writable"; fi
  done

  # bind-mounted network filesystems
  for d in /n /net; do
    if [ -d "${d}" ] && [ -n "$(ls -A "${d}" 2>/dev/null)" ]; then
      pass "fs/bind${d}"
    else
      fail "fs/bind${d}" "missing or empty inside the container"
    fi
  done

  if [ -w "${HOME}" ]; then pass "fs/home-writable" "${HOME}"; else fail "fs/home-writable" "${HOME}"; fi
}

#-----------------------------------------------------------------------------
# group: slurm
#-----------------------------------------------------------------------------

test_slurm() {
  header "Slurm integration"

  # Job-submission commands are deliberately replaced by a stub that exits 1
  local cmd out rc
  for cmd in sbatch srun salloc scrontab; do
    out=$(run_cmd "${cmd}" --version 2>&1); rc=$?
    printf '%s\n' "${out}" | log_block "${cmd} --version (exit ${rc})"
    if [ ${rc} -ne 0 ] && printf '%s' "${out}" | grep -q 'cannot be run within the RStudio Server container'; then
      pass "slurm/${cmd}-stubbed"
    else
      fail "slurm/${cmd}-stubbed" "expected the stub message and a non-zero exit, got exit ${rc}"
    fi
  done

  # Query commands are bind-mounted from the host and must work
  for cmd in squeue sinfo sacct scontrol sshare; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
      fail "slurm/${cmd}-works" "not found in the container"
      continue
    fi
    case ${cmd} in
      squeue)   out=$(run_cmd squeue -u "${USER}" 2>&1) ;;
      sinfo)    out=$(run_cmd sinfo --version 2>&1) ;;
      sacct)    out=$(run_cmd sacct -n -X -j "${SLURM_JOB_ID:-1}" 2>&1) ;;
      scontrol) out=$(run_cmd scontrol version 2>&1) ;;
      sshare)   out=$(run_cmd sshare -U 2>&1) ;;
    esac
    rc=$?
    printf '%s\n' "${out}" | log_block "${cmd} (exit ${rc})"
    if [ ${rc} -eq 0 ]; then
      pass "slurm/${cmd}-works"
    else
      fail "slurm/${cmd}-works" "exit ${rc}; see ${LOG}"
    fi
  done
}

#-----------------------------------------------------------------------------
# group: r  (pinned CRAN date, install location, availableCores)
#-----------------------------------------------------------------------------

test_r() {
  header "R packages"

  # 1. pinned date: the CRAN repo URL must carry a YYYY-MM-DD, not "latest"
  local f; f=$(r_file repos)
  cat >>"${f}" <<'EOF'
repos <- getOption("repos")
cran  <- if ("CRAN" %in% names(repos)) repos[["CRAN"]] else repos[[1]]
ok(grepl("[0-9]{4}-[0-9]{2}-[0-9]{2}", cran) && !grepl("latest", cran),
   "r/repo-pinned-to-date", cran)
ok(nzchar(Sys.getenv("R_LIBS_USER")) && dir.exists(Sys.getenv("R_LIBS_USER")),
   "r/lib-dir-exists", Sys.getenv("R_LIBS_USER"))
EOF
  run_r "r/repos" "${f}"

  # 2. an actual install must download from the dated URL and land in R_LIBS_USER
  local out rc
  out=$(run_cmd Rscript -e 'install.packages("parallelly")' 2>&1); rc=$?
  printf '%s\n' "${out}" | log_block "install.packages(\"parallelly\") (exit ${rc})"

  local url
  url=$(printf '%s\n' "${out}" | sed -n "s/.*trying URL '\([^']*\)'.*/\1/p" | head -1)
  if [ -z "${url}" ]; then
    fail "r/install-url-pinned" "no 'trying URL' line -- nothing was downloaded; these tests must run from an empty home directory. See ${LOG}"
  elif printf '%s' "${url}" | grep -Eq '[0-9]{4}-[0-9]{2}-[0-9]{2}' && ! printf '%s' "${url}" | grep -q latest; then
    pass "r/install-url-pinned" "${url}"
  else
    fail "r/install-url-pinned" "not a pinned date: ${url}"
  fi

  if printf '%s\n' "${out}" | grep -Fq "${R_LIBS_USER:-__unset__}"; then
    pass "r/install-into-R_LIBS_USER" "${R_LIBS_USER}"
  else
    fail "r/install-into-R_LIBS_USER" "install did not report ${R_LIBS_USER:-<unset>}; see ${LOG}"
  fi

  if [ ${rc} -ne 0 ]; then
    fail "r/install-parallelly" "Rscript exited ${rc}; see ${LOG}"
    return
  fi
  pass "r/install-parallelly"

  # 3. availableCores(): /proc/self/status and nproc must equal the allocation,
  #    and a BiocParallel column would mean Renviron.site was not overridden
  f=$(r_file cores)
  cat >>"${f}" <<'EOF'
expected <- Sys.getenv("RUN_TESTS_EXPECTED_CPUS")
if (!requireNamespace("parallelly", quietly = TRUE)) {
  res("FAIL", "r/availableCores", "parallelly is not installed")
} else {
  ac <- parallelly::availableCores(which = "all")
  detail <- paste(sprintf("%s=%s", names(ac), ac), collapse = " ")
  ok(!any(grepl("BiocParallel", names(ac))), "r/no-BiocParallel-column", detail)
  omp <- Sys.getenv("OMP_NUM_THREADS")
  if (nzchar(expected)) {
    ok(identical(omp, expected), "r/OMP_NUM_THREADS-matches-allocation",
       sprintf("OMP_NUM_THREADS=%s expected=%s", omp, expected))
    for (k in c("/proc/self/status", "nproc")) {
      if (k %in% names(ac))
        ok(as.character(ac[[k]]) == expected, paste0("r/availableCores[", k, "]"),
           sprintf("%s=%s expected=%s", k, ac[[k]], expected))
    }
  } else {
    res("SKIP", "r/OMP_NUM_THREADS-matches-allocation", "CPU count unknown; pass --cpus N")
  }
  res("PASS", "r/availableCores", detail)
}
EOF
  export RUN_TESTS_EXPECTED_CPUS=${EXPECTED_CPUS}
  run_r "r/cores" "${f}"
}

#-----------------------------------------------------------------------------
# group: venv  (reticulate virtualenv)
#-----------------------------------------------------------------------------

# The numpy/pandas/scipy snippet the document runs by hand in reticulate::repl_python(),
# rewritten as assertions and run with reticulate::py_run_file().
PY_SNIPPET="${TMPD}/snippet.py"
cat >"${PY_SNIPPET}" <<'EOF'
import numpy as np
a = np.arange(6)
a2 = a[np.newaxis, :]
assert a2.shape == (1, 6), a2.shape

import pandas as pd
from scipy.linalg import inv
df = pd.DataFrame(np.random.rand(5, 5), columns=list("abcde"))
assert np.allclose(df.values @ inv(df), np.eye(5)), "scipy.linalg.inv is wrong"
assert list(df.transpose().index) == list("abcde")
print("python snippet ok:", np.__version__, pd.__version__)
EOF
export RUN_TESTS_PY_SNIPPET="${PY_SNIPPET}"

test_venv() {
  header "reticulate: virtualenv r-reticulate"

  # phase 1: create the env and install packages
  local f; f=$(r_file venv_install)
  cat >>"${f}" <<'EOF'
if (!requireNamespace("reticulate", quietly = TRUE)) install.packages("reticulate")
ok(requireNamespace("reticulate", quietly = TRUE), "venv/reticulate-installed",
   as.character(utils::packageVersion("reticulate")))
library(reticulate)
if (!virtualenv_exists("r-reticulate")) {
  try_ok(virtualenv_create("r-reticulate"), "venv/create-r-reticulate")
} else {
  res("FAIL", "venv/create-r-reticulate",
      "r-reticulate already exists -- these tests must run from an empty home directory")
}
try_ok(virtualenv_install("r-reticulate", c("numpy", "pandas", "scipy")),
       "venv/install-numpy-pandas-scipy")
py <- tryCatch(virtualenv_python("r-reticulate"), error = function(e) "")
root <- Sys.getenv("RETICULATE_VIRTUALENV_ROOT")
# Compare the virtualenv *directory*, not the python binary: <venv>/bin/python
# is a symlink to the system interpreter, so normalizePath() would resolve it
# straight out of the virtualenv and the check would always fail.
if (nzchar(root)) {
  vdir  <- if (nzchar(py)) normalizePath(dirname(dirname(py)), mustWork = FALSE) else ""
  nroot <- normalizePath(root, mustWork = FALSE)
  ok(nzchar(py) && startsWith(vdir, nroot),
     "venv/python-under-RETICULATE_VIRTUALENV_ROOT",
     sprintf("%s (venv dir %s vs root %s)", py, vdir, nroot))
} else {
  res("PASS", "venv/python-path", py)
}
EOF
  run_r "venv/install" "${f}" || return

  # phase 2: fresh R session (equivalent to "Session -> Restart R")
  f=$(r_file venv_use)
  cat >>"${f}" <<'EOF'
library(reticulate)
try_ok(use_virtualenv("r-reticulate", required = TRUE), "venv/use_virtualenv")
try_ok({ scipy <- import("scipy"); pd <- import("pandas"); np <- import("numpy") },
       "venv/import-modules")
cfg  <- py_config()
root <- Sys.getenv("RETICULATE_VIRTUALENV_ROOT")
# again: the venv directory, not the symlinked python binary
if (nzchar(root)) {
  vdir  <- normalizePath(dirname(dirname(cfg$python)), mustWork = FALSE)
  nroot <- normalizePath(root, mustWork = FALSE)
  ok(startsWith(vdir, nroot), "venv/py_config-python-path",
     sprintf("%s (venv dir %s vs root %s)", cfg$python, vdir, nroot))
} else {
  res("PASS", "venv/py_config-python-path", cfg$python)
}
res("PASS", "venv/python-version", as.character(cfg$version))
try_ok(py_run_file(Sys.getenv("RUN_TESTS_PY_SNIPPET")), "venv/numpy-pandas-scipy-compute")
EOF
  run_r "venv/use" "${f}"
}

#-----------------------------------------------------------------------------
# group: conda  (reticulate miniconda)
#-----------------------------------------------------------------------------

test_conda() {
  header "reticulate: miniconda r-conda"

  local f; f=$(r_file conda_install)
  cat >>"${f}" <<'EOF'
if (!requireNamespace("reticulate", quietly = TRUE)) install.packages("reticulate")
library(reticulate)
mp <- tryCatch(miniconda_path(), error = function(e) "")
res("PASS", "conda/miniconda_path", mp)
if (!dir.exists(file.path(mp, "bin"))) {
  try_ok(install_miniconda(), "conda/install_miniconda")
} else {
  res("FAIL", "conda/install_miniconda",
      "miniconda is already installed -- these tests must run from an empty home directory")
}
envs <- tryCatch(conda_list()$name, error = function(e) character())
if (!("r-conda" %in% envs)) {
  try_ok(conda_create("r-conda", python_version = "3.12"), "conda/conda_create")
} else {
  res("FAIL", "conda/conda_create",
      "r-conda already exists -- these tests must run from an empty home directory")
}
try_ok(conda_install("r-conda", c("scipy", "pandas")), "conda/conda_install")
EOF
  run_r "conda/install" "${f}" || return

  f=$(r_file conda_use)
  cat >>"${f}" <<'EOF'
library(reticulate)
try_ok(use_condaenv("r-conda", required = TRUE), "conda/use_condaenv")
try_ok({ scipy <- import("scipy"); pd <- import("pandas") }, "conda/import-modules")
cfg <- py_config()
mp  <- Sys.getenv("RETICULATE_MINICONDA_PATH")
# conda installs a real python binary rather than a symlink, but compare the
# env directory anyway so this does not depend on that staying true
if (nzchar(mp)) {
  edir <- normalizePath(dirname(dirname(cfg$python)), mustWork = FALSE)
  nmp  <- normalizePath(mp, mustWork = FALSE)
  ok(startsWith(edir, nmp), "conda/py_config-under-RETICULATE_MINICONDA_PATH",
     sprintf("%s (env dir %s vs root %s)", cfg$python, edir, nmp))
} else {
  res("PASS", "conda/py_config-python-path", cfg$python)
}
res("PASS", "conda/python-version", as.character(cfg$version))
try_ok(py_run_file(Sys.getenv("RUN_TESTS_PY_SNIPPET")), "conda/numpy-pandas-scipy-compute")
EOF
  run_r "conda/use" "${f}"
}

#-----------------------------------------------------------------------------
# group: pip  (RELEASE <= 3.19 only)
#-----------------------------------------------------------------------------

test_pip() {
  header "pip installs into PYTHONUSERBASE"

  if ! version_le 19; then
    skip "pip/*" "a pip user base is only used by RELEASE <= 3.19 (this is ${image_tag:-unknown})"
    return
  fi

  # Users are told to run a plain "pip install", relying on pip printing
  # "Defaulting to user installation because normal site-packages is not
  # writeable" and installing into PYTHONUSERBASE. pip only does that when it is
  # NOT inside a virtualenv: if the image ships an active venv (Bioconductor
  # >= 3.19 has /opt/venv), pip targets that venv instead -- read-only here --
  # and PYTHONUSERBASE is bypassed however it is set. That is a KNOWN FAILURE on
  # RELEASE_3_19 that is not being fixed (RELEASE >= 3.20 drops the pip user
  # base entirely), so report it as a SKIP rather than a FAIL. Detect it up
  # front: otherwise the first pip tests pass vacuously ("Requirement already
  # satisfied" from the venv) and only the first command that writes fails.
  local py_prefix=""
  if command -v python >/dev/null 2>&1; then
    py_prefix=$(python -c 'import sys; print("" if sys.prefix == sys.base_prefix else sys.prefix)' 2>/dev/null)
  fi
  if [ -n "${VIRTUAL_ENV:-}" ] || [ -n "${py_prefix}" ]; then
    skip "pip/*" \
         "KNOWN FAILURE, not being fixed: pip runs inside the virtualenv ${VIRTUAL_ENV:-${py_prefix}}, so it installs there rather than into PYTHONUSERBASE (${PYTHONUSERBASE:-<unset>}); --user is refused too. Use reticulate on this release -- see the note in test_sing_images.md"
    return
  fi
  pass "pip/no-active-virtualenv"

  local out rc
  out=$(run_cmd pip install numpy 2>&1); rc=$?
  printf '%s\n' "${out}" | log_block "pip install numpy (exit ${rc})"
  if [ ${rc} -eq 0 ]; then pass "pip/install-numpy"; else fail "pip/install-numpy" "exit ${rc}"; fi

  out=$(run_cmd pip list 2>&1); rc=$?
  printf '%s\n' "${out}" | log_block "pip list (exit ${rc})"
  if printf '%s' "${out}" | grep -qi '^numpy'; then
    pass "pip/list-shows-numpy"
  else
    fail "pip/list-shows-numpy" "see ${LOG}"
  fi

  out=$(run_cmd pip install pelican 2>&1); rc=$?
  printf '%s\n' "${out}" | log_block "pip install pelican (exit ${rc})"
  if [ ${rc} -ne 0 ]; then
    fail "pip/install-pelican" "exit ${rc}"
  else
    pass "pip/install-pelican"
    local where; where=$(command -v pelican 2>/dev/null)
    case ${where} in
      "${PYTHONUSERBASE:-__unset__}"/bin/pelican) pass "pip/pelican-on-PATH" "${where}" ;;
      "") fail "pip/pelican-on-PATH" "pelican not on PATH" ;;
      *)  fail "pip/pelican-on-PATH" "expected ${PYTHONUSERBASE:-<unset>}/bin/pelican, got ${where}" ;;
    esac
    out=$(run_cmd pelican --version 2>&1); rc=$?
    printf '%s\n' "${out}" | log_block "pelican --version (exit ${rc})"
    if [ ${rc} -eq 0 ]; then pass "pip/pelican-runs" "${out}"; else fail "pip/pelican-runs" "exit ${rc}"; fi
  fi

  # upgrade path
  out=$(run_cmd pip install --upgrade numpy 2>&1); rc=$?
  printf '%s\n' "${out}" | log_block "pip install --upgrade numpy (exit ${rc})"
  if [ ${rc} -eq 0 ]; then pass "pip/upgrade-numpy"; else fail "pip/upgrade-numpy" "exit ${rc}"; fi

  if [ ${DO_SPACY} -ne 1 ]; then
    skip "pip/spacy" "slow; rerun with --spacy"
    return
  fi
  out=$(run_cmd pip install spacy 2>&1); rc=$?
  printf '%s\n' "${out}" | log_block "pip install spacy (exit ${rc})"
  if [ ${rc} -ne 0 ]; then fail "pip/install-spacy" "exit ${rc}"; return; fi
  pass "pip/install-spacy"

  out=$(run_cmd python -m spacy download en_core_web_sm 2>&1); rc=$?
  printf '%s\n' "${out}" | log_block "spacy download en_core_web_sm (exit ${rc})"
  if [ ${rc} -eq 0 ]; then pass "pip/spacy-model"; else fail "pip/spacy-model" "exit ${rc}"; fi

  local f; f=$(r_file spacyr)
  cat >>"${f}" <<'EOF'
if (!requireNamespace("spacyr", quietly = TRUE)) install.packages("spacyr")
try_ok(library(spacyr), "pip/spacyr-loads")
EOF
  run_r "pip/spacyr" "${f}"
}

#-----------------------------------------------------------------------------
# tests that cannot be automated
#-----------------------------------------------------------------------------

test_manual() {
  header "Manual tests (not automated)"
  skip "manual/tensorflow-gpu" "RELEASE <= 3.18 only, needs a GPU node: see the TensorFlow section of test_sing_images.md"
  skip "manual/rstudio-ide" "IDE-only checks (Session -> Restart R, Copilot / Posit Assistant panes)"
  skip "manual/vanillaconf-checkbox" "launch the app twice (box checked / unchecked) and compare fs/user-state-dir-is-mount"
}

#-----------------------------------------------------------------------------
# main
#-----------------------------------------------------------------------------

printf '%s%s%s\n' "${C_HDR}" "RStudio Server Singularity image tests" "${C_OFF}"
printf 'host          : %s\n' "$(hostname)"
printf 'container     : %s\n' "${container_desc}"
printf 'R_LIBS_USER   : %s\n' "${R_LIBS_USER:-<unset>}"
printf 'release       : %s\n' "${image_tag:-<unknown>}"
printf 'CPUs expected : %s\n' "${EXPECTED_CPUS:-<unknown>}"
printf 'groups        : %s\n' "$(for g in ${ALL_GROUPS}; do group_enabled "${g}" && printf '%s ' "${g}"; done)"
printf 'log           : %s\n' "${LOG}"

{
  printf 'run_tests.sh %s\n' "$(date)"
  printf 'host=%s R_LIBS_USER=%s release=%s cpus=%s\n' \
    "$(hostname)" "${R_LIBS_USER:-}" "${image_tag:-}" "${EXPECTED_CPUS:-}"
  printf 'env:\n'; env | sort
} >>"${LOG}"

if ! command -v Rscript >/dev/null 2>&1; then
  printf '\n%s: Rscript not found -- are you running this outside the container?\n' "${PROG}" >&2
  exit 1
fi

group_enabled env   && test_env
group_enabled fs    && test_fs
group_enabled slurm && test_slurm
group_enabled r     && test_r
group_enabled venv  && test_venv
group_enabled conda && test_conda
group_enabled pip   && test_pip
test_manual

header "Summary"
printf '  passed : %d\n  failed : %d\n  skipped: %d\n' "${n_pass}" "${n_fail}" "${n_skip}"
if [ -n "${failed_tests}" ]; then
  printf '\n%sFailed:%s\n' "${C_FAIL}" "${C_OFF}"
  printf '%s' "${failed_tests}" | sed 's/^/  - /'
fi
if [ -n "${skipped_tests}" ]; then
  printf '\n%sSkipped:%s\n' "${C_SKIP}" "${C_OFF}"
  printf '%s' "${skipped_tests}" | sed 's/^/  - /'
fi
printf '\nfull output: %s\n' "${LOG}"

[ "${n_fail}" -eq 0 ]
