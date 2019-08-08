# 2019-08 workshop
# RStudio + tidyverse + Seurat + iSEE
FROM rocker/tidyverse:3.6.1

RUN apt install -y --no-install-recommends libpython3-dev python3-setuptools python3-pip && \
    pip3 install --no-cache-dir umap-learn
RUN install2.r Seurat && rm -rf /tmp/*
# umap required by iSEE; libpython3-dev provides libpython (required for reticulate to use umap)
RUN Rscript -e 'BiocManager::install(c("DESeq2", "biomaRt", "edgeR", "limma", "rhdf5"), update=FALSE, ask=FALSE)'
# https://pachterlab.github.io/sleuth/download
RUN Rscript -e 'devtools::install_github("pachterlab/sleuth")'
