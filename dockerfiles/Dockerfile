FROM bioconductor/bioconductor_full:RELEASE_3_9

######## union rocker/tidyverse
# https://github.com/rocker-org/rocker-versioned/blob/c0ae40/tidyverse/Dockerfile
# with the following packages omitted:
#   libxml2-dev - already installed
#   libcairo2-dev - already installed
#   libsqlite3-dev  - already installed
#   libmariadb-client-lgpl-dev - noop when libmariadb-dev is already installed
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
ENV PATH=$PATH:/opt/TinyTeX/bin/x86_64-linux/

## Add LaTeX, rticles and bookdown support
RUN wget "https://travis-bin.yihui.name/texlive-local.deb" \
  && dpkg -i texlive-local.deb \
  && rm texlive-local.deb \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
    ## for some package installs
	cmake \
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
  && /opt/TinyTeX/bin/*/tlmgr path add \
  && tlmgr install ae inconsolata listings metafont mfware parskip pdfcrop tex \
  && tlmgr path add \
  && Rscript -e "tinytex::r_texmf()" \
  && chown -R root:staff /opt/TinyTeX \
  && chown -R root:staff /usr/local/lib/R/site-library \
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

# sleuth
RUN Rscript -e 'BiocManager::install(c("DESeq2", "biomaRt", "edgeR", "limma", "rhdf5"), update=FALSE, ask=FALSE)'
# https://pachterlab.github.io/sleuth/download
RUN Rscript -e 'devtools::install_github("pachterlab/sleuth")'

######## for adsouza
RUN install2.r seqinr MKmisc && rm -rf /tmp/*
RUN Rscript -e 'BiocManager::install(c("MSnbase", "ROTS"), update=FALSE, ask=FALSE)'

####### for 2019-11 FAS Informatics workshops
RUN install2.r R2jags arm lme4 && rm -rf /tmp/*

####### for afreedman's differential expression workshop (suggested dependency of limma)
RUN install2.r statmod && rm -rf /tmp/*
