# RStudio Server

RStudio Server singularity images used to be from [rocker
project](https://github.com/rocker-org/rocker-versioned2). Since release 3.16,
they come from [Bioconductor
ml-verse](https://github.com/Bioconductor/bioconductor_docker/pkgs/container/ml-verse)to provide GPU support.

## `R_LIBS_USER`

`R_LIBS_USER` is set to `$HOME/R/ifxrstudio:${TAG}`, e.g. `RELEASE_3_13`

## R packages pinned version

R packages in RStudio Server are tied to a specific CRAN version.

FASRC serves a very wide range of researchers that use RStudio, from geospacial
to informatics as well as a big group in the social sciences. This means that
we have to be able to install many different R packages. When we install R
packages directly in the cluster's OS, we have to select the right compilers,
libraries, etc. This proved to be very time consuming for us and made users
very frustrated.

Our solution was to develop a Singularity container with RStudio Server and many
of the packages precompiled to ensure an easy installation (for most cases) for
users. To implement this, we use the [rocker project](https://github.com/rocker-org/rocker-versioned2). The upstream (rocker) project
pins to particular date for all R versions (except the latest version), and our
(Singularity) images inherit that pinning; e.g. see this [dockerfile](
https://github.com/rocker-org/rocker-versioned2/blob/23b6961dcc187b7290b35ae4434180dfb1fa7f24/dockerfiles/r-ver_4.2.1.Dockerfile#L16).

The rationale for this is described a bit more in this [GitHub
issue](https://github.com/rocker-org/rocker-versioned2/issues/201) which links
to this page with the list of [pinned CRAN
versions](https://github.com/rocker-org/rocker-versioned2/wiki/Versions).

On release 3.16, Nathan Weeks changed to the [Bioconductor
ml-verse](https://github.com/Bioconductor/bioconductor_docker/pkgs/container/ml-verse)
project to support GPUs. The same pinning is ensured because
bioconductor_docker:ml-verse uses the upstream rocker/ml-verse base image --
e.g., see this
[dockerfile](https://github.com/rocker-org/rocker-versioned2/blob/f7161ec6d4310518df14a5ab47fdde098c8764fb/dockerfiles/ml-verse_4.3.3.Dockerfile#L10)
for release 3.18.

However, the pinned date drawback is that newer packages (installed from
source) may depend on newer versions of CRAN packages than exist at the pinned
date.

After implementing this approach of using precompiled binaries packages, we
noticed a big improvement for the majority of users and a considerable decrease
in tickets requesting help with R packages. Unfortunately, there will always be
edge cases. But, overall, this pinned version has worked well.

