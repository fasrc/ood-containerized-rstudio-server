FROM bioconductor/bioconductor_docker:RELEASE_3_12

# work around install_tidyverse.sh default-libmysqlclient-dev installation problem in RELEASE_3_12
RUN apt update \
  && apt install -y --no-install-recommends libmysqlclient-dev \
  && rm -rf /var/lib/apt/lists/*

######## union rocker/tidyverse
# https://github.com/rocker-org/rocker-versioned2/blob/master/dockerfiles/Dockerfile_tidyverse_4.0.3
RUN /rocker_scripts/install_tidyverse.sh

######## union rocker/verse
# https://github.com/rocker-org/rocker-versioned2/blob/master/dockerfiles/Dockerfile_verse_4.0.3
ENV CTAN_REPO=http://mirror.ctan.org/systems/texlive/tlnet
ENV PATH=/usr/local/texlive/bin/x86_64-linux:$PATH
RUN /rocker_scripts/install_verse.sh

######## union rocker/geospatial
# https://github.com/rocker-org/rocker-versioned2/blob/master/dockerfiles/Dockerfile_geospatial_4.0.3
RUN /rocker_scripts/install_geospatial.sh

######## union rocker/ml
#ENV PYTHON_VENV_PATH=/opt/venv/reticulate
#ENV PATH=${PYTHON_VENV_PATH}/bin:${PATH}
#RUN /rocker_scripts/install_tensorflow.sh

# Install default & yihui TinyTex latex package sets to allow knit-to-PDF
# (hopefully in most cases) without installation of additional LaTeX packages,
# as /usr/local/texlive is read-only in the Singularity image
RUN tlmgr install $(curl https://raw.githubusercontent.com/yihui/tinytex/v0.27/tools/pkgs-custom.txt | tr '\n' ' ')
RUN tlmgr install $(curl https://raw.githubusercontent.com/yihui/tinytex/v0.27/tools/pkgs-yihui.txt | tr '\n' ' ')
