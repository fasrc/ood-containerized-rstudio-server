# https://software.intel.com/en-us/articles/how-to-use-zlib-with-intel-ipp-optimization

FROM intel/oneapi-hpckit:2021.1-47.beta03-devel-ubuntu18.04 AS oneapi

RUN apt install -y wget 

SHELL ["/bin/bash", "-c"]

RUN wget -O - https://github.com/madler/zlib/archive/v1.2.11.tar.gz | tar -xzf - \
 && cd zlib-1.2.11 \
 && source /opt/intel/inteloneapi/setvars.sh > /dev/null \
 && tar -xzvf $IPPROOT/components/components_and_examples_lin.tgz \
 && patch -p1 < components/interfaces/ipp_zlib/zlib-1.2.11.patch \
 && export CFLAGS="-m64 -DWITH_IPP -I$IPPROOT/include" \
 && export LDFLAGS="-L$IPPROOT/lib/intel64 -lippdc -lipps -lippcore" \
 && ./configure --prefix=/artifacts/zlib \
 && make shared \
 && make install

# wildcard "*" doesn't seem to work in "COPY --from" source?

RUN find /opt/intel/inteloneapi/ipp/latest/lib/intel64/ -maxdepth 1 -mindepth 1 ! \(  -type f -name '*.so' \) -exec rm -rf {} +

FROM bioconductor/bioconductor_docker:RELEASE_3_10 AS final

COPY --from=oneapi /artifacts/zlib/lib/libz.so.1.2.11 /lib/x86_64-linux-gnu/libz.so.1.2.11
COPY --from=oneapi /opt/intel/inteloneapi/ipp/latest/lib/intel64/ /usr/local/lib/

RUN ldconfig

# https://github.com/eddelbuettel/mkl4deb/issues/8#issuecomment-548949944
# https://github.com/eddelbuettel/mkl4deb/blob/master/README.md#integrate-mkl
# https://github.com/eddelbuettel/mkl4deb/issues/8#issuecomment-548943912
RUN sed -i'' '/^deb /s/$/ non-free/' /etc/apt/sources.list \
 && apt update \
 && apt remove -y libopenblas-base \
 && apt install -y --no-install-recommends intel-mkl \
 && update-alternatives --install /usr/lib/x86_64-linux-gnu/libblas.so libblas.so-x86_64-linux-gnu /usr/lib/x86_64-linux-gnu/libmkl_rt.so 150 \
 && update-alternatives --install /usr/lib/x86_64-linux-gnu/libblas.so.3 libblas.so.3-x86_64-linux-gnu /usr/lib/x86_64-linux-gnu/libmkl_rt.so 150 \
 && update-alternatives --install /usr/lib/x86_64-linux-gnu/liblapack.so liblapack.so-x86_64-linux-gnu /usr/lib/x86_64-linux-gnu/libmkl_rt.so 150 \
 && update-alternatives --install /usr/lib/x86_64-linux-gnu/liblapack.so.3 liblapack.so.3-x86_64-linux-gnu /usr/lib/x86_64-linux-gnu/libmkl_rt.so 150 \
 && update-alternatives --install /usr/lib/x86_64-linux-gnu/libopenblas.so libopenblas.so-x86_64-linux-gnu /usr/lib/x86_64-linux-gnu/libmkl_rt.so 150 \
 && update-alternatives --install /usr/lib/x86_64-linux-gnu/libopenblas.so.0 libopenblas.so.0-x86_64-linux-gnu /usr/lib/x86_64-linux-gnu/libmkl_rt.so 150 \
 && rm -rf /var/lib/apt/lists/

######## union rocker/tidyverse
# https://github.com/rocker-org/rocker-versioned/blob/c0ae40/tidyverse/Dockerfile
# with the following packages omitted:
#   libxml2-dev - already installed
#   libcairo2-dev - already installed
#   libsqlite-dev  - already installed
#   libmariadb-client- already installed
#   libpq-dev - already installed
# and subsequently removing files from /tmp:
#   https://github.com/rocker-org/shiny/issues/68
RUN apt-get update -qq && apt-get -y --no-install-recommends install \
  libmariadbd-dev \
  libssh2-1-dev \
  && install2.r --error \
    --deps TRUE \
    tidyverse \
    dplyr \
    devtools \
    formatR \
    remotes \
    selectr \
    caTools \
  && rm -rf /tmp/*

########## union rocker/verse
# https://github.com/rocker-org/rocker-versioned/blob/4d6def/verse/Dockerfile

# Version-stable CTAN repo from the tlnet archive at texlive.info, used in the
# TinyTeX installation: chosen as the frozen snapshot of the TeXLive release
# shipped for the base Debian image of a given rocker/r-ver tag.
# Debian buster => TeXLive 2018, frozen release snapshot 2019/02/27
ARG CTAN_REPO=${CTAN_REPO:-https://www.texlive.info/tlnet-archive/2019/02/27/tlnet}
ENV CTAN_REPO=${CTAN_REPO}

ENV PATH=$PATH:/opt/TinyTeX/bin/x86_64-linux/

## Add LaTeX, rticles and bookdown support
RUN wget "https://travis-bin.yihui.name/texlive-local.deb" \
  && dpkg -i texlive-local.deb \
  && rm texlive-local.deb \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
    ## for rJava
    default-jdk \
    ## Nice Google fonts
    fonts-roboto \
    ## used by some base R plots
    ghostscript \
    ## used to build rJava and other packages
    libbz2-dev \
    libicu-dev \
    liblzma-dev \
    ## system dependency of hunspell (devtools)
    libhunspell-dev \
    ## system dependency of hadley/pkgdown
    libmagick++-dev \
    ## rdf, for redland / linked data
    librdf0-dev \
    ## for V8-based javascript wrappers
    libv8-dev \
    ## R CMD Check wants qpdf to check pdf sizes, or throws a Warning
    qpdf \
    ## For building PDF manuals
    texinfo \
    ## for git via ssh key
    ssh \
 ## just because
    less \
    vim \
 ## parallelization
    libzmq3-dev \
    libopenmpi-dev \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/ \
  ## Use tinytex for LaTeX installation
  && install2.r --error tinytex \
  ## Admin-based install of TinyTeX:
  && wget -qO- \
    "https://github.com/yihui/tinytex/raw/master/tools/install-unx.sh" | \
    sh -s - --admin --no-path \
  && mv ~/.TinyTeX /opt/TinyTeX \
  && if /opt/TinyTeX/bin/*/tex -v | grep -q 'TeX Live 2018'; then \
      ## Patch the Perl modules in the frozen TeX Live 2018 snapshot with the newer
      ## version available for the installer in tlnet/tlpkg/TeXLive, to include the
      ## fix described in https://github.com/yihui/tinytex/issues/77#issuecomment-466584510
      ## as discussed in https://www.preining.info/blog/2019/09/tex-services-at-texlive-info/#comments
      wget -P /tmp/ ${CTAN_REPO}/install-tl-unx.tar.gz \
      && tar -xzf /tmp/install-tl-unx.tar.gz -C /tmp/ \
      && cp -Tr /tmp/install-tl-*/tlpkg/TeXLive /opt/TinyTeX/tlpkg/TeXLive \
      && rm -r /tmp/install-tl-*; \
    fi \
  && /opt/TinyTeX/bin/*/tlmgr path add \
  && tlmgr install ae inconsolata listings metafont mfware parskip pdfcrop tex \
  && tlmgr path add \
  && Rscript -e "tinytex::r_texmf()" \
  && chown -R root:staff /opt/TinyTeX \
  && chmod -R g+w /opt/TinyTeX \
  && chmod -R g+wx /opt/TinyTeX/bin \
  && echo "PATH=${PATH}" >> /usr/local/lib/R/etc/Renviron \
  && install2.r --error PKI \
  ## And some nice R packages for publishing-related stuff
  && install2.r --error --deps TRUE \
    bookdown rticles rmdshower rJava \
  && rm -rf /tmp/*

######## for mtang
# Seurat python dependency
RUN pip install --no-cache-dir umap-learn

RUN install2.r Seurat && rm -rf /tmp/*

####### 2019-08 DE nanocourse
# https://github.com/harvardinformatics/micro-course/blob/nanocourse_2019/bulkRNAseq/DE/differential_expression_nanocourse2019.Rmd
RUN Rscript -e 'BiocManager::install(c("DESeq2", "biomaRt", "edgeR", "limma", "rhdf5"), update=FALSE, ask=FALSE)'

####### sleuth
# https://pachterlab.github.io/sleuth/download
RUN installGithub.r --update FALSE pachterlab/sleuth@4e221a16117ff4a3bdc56feeca4f69b30d17fec8
 
####### for adsouza
RUN install2.r seqinr MKmisc && rm -rf /tmp/*
RUN Rscript -e 'BiocManager::install(c("MSnbase", "ROTS"), update=FALSE, ask=FALSE)'

####### for tsackton & dkhost's 2019-11 workshop
RUN install2.r R2jags arm lme4 && rm -rf /tmp/*

####### for afreedman's 2019-11 differential expression workshop (suggested dependency of limma)
RUN install2.r statmod && rm -rf /tmp/*
