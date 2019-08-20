# RStudio + tidyverse + Seurat + iSEE
FROM rocker/tidyverse:3.6.1

RUN apt install -y --no-install-recommends libpython3-dev python3-setuptools python3-pip && \
    pip3 install --no-cache-dir umap-learn
RUN install2.r Seurat && rm -rf /tmp/*
# umap required by iSEE; libpython3-dev provides libpython (required for reticulate to use umap)
RUN Rscript -e 'BiocManager::install(c("DESeq2", "biomaRt", "edgeR", "limma", "rhdf5"), update=FALSE, ask=FALSE)'
# https://pachterlab.github.io/sleuth/download
RUN Rscript -e 'devtools::install_github("pachterlab/sleuth")'

# pong for John's popgen workshop (https://github.com/ramachandran-lab/pong)
RUN apt install -y --no-install-recommends python-pip python-decorator python-munkres python-networkx python-numpy python-tornado \
    && pip install --no-cache-dir pong \
    && apt remove -y python-pip

# modifications to allow pong to be hosted from url path other than / and support HTTPS
# from https://github.com/nathanweeks/pong/commit/f1153b5f235abecebcd2d884b40736cf58262004
# with modifications run_pong.py -> pong from pypi version
# and minification of pong.js & pong.css with yui-compressor
COPY ./pong.min.css /usr/local/lib/python2.7/dist-packages/pong/static/pong.min.css
COPY ./pong.min.js /usr/local/lib/python2.7/dist-packages/pong/static/pong.min.js
COPY ./pong /usr/local/bin/pong
RUN chmod 555 /usr/local/bin/pong
