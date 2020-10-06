FROM bioconductor/bioconductor_docker:RELEASE_3_11

######## union rocker/tidyverse
# https://github.com/rocker-org/rocker-versioned2/blob/master/dockerfiles/Dockerfile_tidyverse_4.0.0-ubuntu18.04
RUN bash /rocker_scripts/install_tidyverse.sh

######## union rocker/verse
# https://github.com/rocker-org/rocker-versioned2/blob/master/dockerfiles/Dockerfile_verse_4.0.0-ubuntu18.04
ENV CTAN_REPO=http://mirror.ctan.org/systems/texlive/tlnet
ENV PATH=/opt/texlive/bin/x86_64-linux:/usr/local/texlive/bin/x86_64-linux:$PATH
RUN /rocker_scripts/install_verse.sh

# Install default & yihui TinyTex latex package sets to allow knit-to-PDF
# (hopefully in most cases) without installation of additional LaTeX packages,
# as /usr/local/texlive and /opt/texlive are read-only in the Singularity image
ADD https://raw.githubusercontent.com/yihui/tinytex/v0.23/tools/pkgs-custom.txt /rocker_scripts/
RUN tlmgr install $(tr '\n' ' ' < /rocker_scripts/pkgs-custom.txt)
ADD https://raw.githubusercontent.com/yihui/tinytex/v0.23/tools/pkgs-yihui.txt /rocker_scripts/
RUN tlmgr install $(tr '\n' ' ' < /rocker_scripts/pkgs-yihui.txt)
