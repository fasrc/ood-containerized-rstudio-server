FROM bioconductor/bioconductor_docker:RELEASE_3_11

######## union rocker/tidyverse
# https://github.com/rocker-org/rocker-versioned2/blob/master/dockerfiles/Dockerfile_tidyverse_4.0.0-ubuntu18.04
# 2020-05-14
ADD https://raw.githubusercontent.com/rocker-org/rocker-versioned2/65309d4d9dac11d3a78dd26ee4bf7b715436db31/scripts/install_tidyverse.sh /rocker_scripts/
RUN bash /rocker_scripts/install_tidyverse.sh


######## union rocker/verse
# https://github.com/rocker-org/rocker-versioned2/blob/master/dockerfiles/Dockerfile_verse_4.0.0-ubuntu18.04
#
# 2020-07-21
ADD https://raw.githubusercontent.com/rocker-org/rocker-versioned2/4aa987d8798d6cfe3e5828806b50e3e0b569a9f5/scripts/install_verse.sh /rocker_scripts/
RUN bash /rocker_scripts/install_verse.sh
