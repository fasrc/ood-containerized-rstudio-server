# 2019-08 workshop
# RStudio + tidyverse + Seurat + iSEE
FROM rocker/tidyverse:3.6.1

RUN install2.r Seurat && rm -rf /tmp/*
# umap required by iSEE; libpython3-dev provides libpython (required for reticulate to use umap)
RUN apt install -y --no-install-recommends libpython3-dev python3-setuptools python3-pip && \
    pip3 install --no-cache-dir umap-learn
RUN Rscript -e 'BiocManager::install("iSEE", update=FALSE, ask=FALSE)'
#RUN export ADD=shiny && bash /etc/cont-init.d/add
