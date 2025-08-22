# Test Singularity Images

This document contains tests that should be performed on a new Singularity image
before it is deployed on Open OnDemand.

The tests were first developed for release 3.15, when Nathan Weeks added
Python-R integration and have evolved for newest releases.

Tests are separated into two categories:

1. Python packages via `pip`: these installs are typically done from the RStudio
   Server terminal.
2. Python packages via R library `reticulate`: these installs are typically done
   from RStudio Server R console/shell.

Directories to delete to "clean" your Python/R environment:

- `~/.local/`
- ` ~/R/ifxrstudio/RELEASE_<version>/`
- `~/.virtualenvs/`

Launch OOD RStudio Server with:

* **Number of CPUs to allocate**: 3

## Filesystem

* **If the "Start rstudio with a new configuration" box was checked**: the RStudio [user state directory](https://docs.posit.co/ide/server-pro/admin/rstudio_pro_sessions/workspace_management.html#user-state-storage) (~/.local/share/rstudio) to be a mountpoint for a scratch filesystem (created by `singularity exec --scratch ...`), the following `findmnt` command should list ~/.local/share/rstudio:

```
nweeks@holy8a24101:~$ findmnt -o TARGET,FSTYPE,SRC -R $(dirname $HOME)
TARGET                                  FSTYPE SOURCE
/n/home12                               nfs    rcstorenfs:/ifs/rc_homes/home12
└─/n/home12/nweeks/.local/share/rstudio xfs    /dev/mapper/vg_root-lv_scratch[/rstudio-server.6P6RkQ/rstudio]
```

* **If the "Start rstudio with a new configuration" box is unchecked**: (or if there is a problem with that feature) then the following `findmnt` command will not reveal filesystem mounted at ~/.local/share/rstudio:

```
nweeks@holy8a24101:~$ findmnt -o TARGET,FSTYPE,SOURCE  $(dirname $HOME)
TARGET    FSTYPE SOURCE
/n/home12 nfs    rcstorenfs:/ifs/rc_homes/home12
```

## R Packages

1. Pinned date

   Ensure that the R packages are comming from a pinned date and **not** latest.

   ```
   > install.packages("parallelly")
   Installing package into ‘/n/home12/nweeks/R/ifxrstudio/RELEASE_3_20’
   (as ‘lib’ is unspecified)
   trying URL 'https://p3m.dev/cran/__linux__/noble/2025-02-27/src/contrib/parallelly_1.42.0.tar.gz'
   Content type 'binary/octet-stream' length 537560 bytes (524 KB)
   ==================================================
   downloaded 524 KB

   * installing *binary* package ‘parallelly’ ...
   * DONE (parallelly)

   The downloaded source packages are in
           ‘/tmp/Rtmp1AiMaa/downloaded_packages’
   ```

   Above, the package is downloaded from `https://p3m.dev/cran/__linux__/noble/2025-02-27/src/contrib/parallelly_1.42.0.tar.gz`
   Note the date `2025-02-27` and not `latest`.


2. CPUs available

   Check that the environment variable `OMP_NUM_THREADS=3`, and the number of available CPUs (determined by `parallelly::availableCores(which="all")` is also 3:

   ```
   > Sys.getenv("OMP_NUM_THREADS")
   [1] "3"
   > parallelly::availableCores(which="all")
              system /proc/self/status             nproc
                 112                 3                 3
   ```

   *FAILURE*: If the environment variable `OMP_NUM_THREADS=2` and `BiocParallel` column is visible (indicating the environment variable `BIOCPARALLEL_NUM_WORKERS=4` is set), then the Bioconductor image's [Renviron.site](https://bioconductor.org/checkResults/devel/bioc-LATEST/Renviron.bioc) was not successfully overwritten.

   ```
   > Sys.getenv("OMP_NUM_THREADS")
   [1] "2"
   > parallelly::availableCores(which="all")
              system /proc/self/status             nproc     BiocParallel
                 112                 3                 3                4
   ```

## Python packages via `pip` (RELEASE <= 3.19)

0. Start RStudio Server with "Start rstudio with a new configuration" checked

1. In RStudio Server terminal, install `numpy` and see `pip list`

   ```bash
   paulasan@holygpu8a22103:~$ pip install numpy
   Defaulting to user installation because normal site-packages is not writeable
   Requirement already satisfied: numpy in /usr/lib/python3/dist-packages (1.21.5)
   
   paulasan@holygpu8a22103:~$ pip list
   Package    Version
   ---------- -------
   GDAL       3.4.1
   numpy      1.21.5
   pip        22.0.2
   setuptools 59.6.0
   wheel      0.37.1
   ```

2. In RStudio Server terminal, install `pelican` and check that `PATH` is properly set

   ```bash
   paulasan@holygpu8a22103:~$ pip install pelican
   ... omitted output ...

   paulasan@holygpu8a22103:~$ type pelican
   pelican is /n/home_rc/paulasan/R/ifxrstudio/RELEASE_3_18/python-user-base/bin/pelican
   paulasan@holygpu8a22103:~$ pelican --version
   4.9.1 
   ```

3. In RStudio Server terminal, install `spacy` and check that it loads in R

   ```bash
   paulasan@holygpu8a22103:~$ pip install spacy
   ... omitted output ...

   paulasan@holygpu8a22103:~$ python -m spacy download en_core_web_sm
   ... omitted output ...
   Successfully installed en-core-web-sm-3.7.1
   ✔ Download and installation successful
   You can now load the package via spacy.load('en_core_web_sm')
   ```

   On R console:

   ```R
   > install.packages("spacyr")
   > library(spacyr)
   ```

4. Run an R script from R console

   Open the file `/n/holylabs/LABS/rc_admin/Everyone/numpy_test.Rmd` on Cannon or  `/n/netscratch/rc_admin/Everyone/numpy_test.Rmd` on FASSE.

   ````bash
   paulasan@holygpu8a22103:~$ cat /n/holylabs/LABS/rc_admin/Everyone/numpy_test.Rmd
   ---
   title: "test_numpy"
   output: html_document
   date: '2022-09-09'
   ---
   
   ```{python}
   import numpy as np
   a = np.arange(6)
   a2 = a[np.newaxis, :]
   a2.shape
   ```
   ````

   You may need to respond Yes/No in the R console:

   ```
   > reticulate::repl_python()
   Would you like to create a default Python environment for the reticulate package? (Yes/no/cancel) no
   Python 3.10.12 (/usr/bin/python3)
   Reticulate 1.36.1 REPL -- A Python interpreter in R.
   Enter 'exit' or 'quit' to exit the REPL and return to R.
   >>> import numpy as np
   >>> a = np.arange(6)
   >>> a2 = a[np.newaxis, :]
   >>> a2.shape
   (1, 6)
   >>>
   ```
  
5. Update existing package

   If you try to install a package and get an output saying `requirement
   already satisfied`, e.g.:

   ```bash
   paulasan@holygpu8a22103:~$ pip install numpy
   Defaulting to user installation because normal site-packages is not writeable
   Requirement already satisfied: numpy in /usr/lib/python3/dist-packages (1.21.5)
   ```

   You can try to upgrade with

   ```bash
   paulasan@holygpu8a22103:~$ pip install numpy --upgrade
   Defaulting to user installation because normal site-packages is not writeable
   Requirement already satisfied: numpy in /usr/lib/python3/dist-packages (1.21.5)
   Collecting numpy
     Downloading numpy-2.0.0-cp310-cp310-manylinux_2_17_x86_64.manylinux2014_x86_64.whl (19.3 MB)
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 19.3/19.3 MB 24.4 MB/s eta 0:00:00
   Installing collected packages: numpy
   Successfully installed numpy-2.0.0
   ```

## Reticulate 

### virtualenv installation

#### Default environment`r-reticulate`

The instructions below were adapted from [reticulate docs](https://rstudio.github.io/reticulate/articles/python_packages.html).

1. Install package in the default virtual environment `r-reticulate`:

   ```R
   > library(reticulate)
   > py_install("pandas")
   Using Python: /usr/bin/python3.10
   Creating virtual environment '~/.virtualenvs/r-reticulate' ...
   > use_virtualenv("r-reticulate")
   > virtualenv_install("r-reticulate", "scipy")
   ```

   It is important to restart R after installing a Python package otherwise you will get an error:

   ```R
   > scipy <- import("scipy")
   Error in py_module_import(module, convert = convert) :
   ModuleNotFoundError: No module named 'scipy'
   ```

   Restart R (Session -> Restart R). Then

   ```R
   > library(reticulate)
   > use_virtualenv("r-reticulate")
   > scipy <- import("scipy")
   > pd <- import("pandas")
   ```

#### Create a`TF` virtualenv and install TensorFlow (RELEASE <= 3.19)

For TensorFlow, ensure that you test on a GPU node.

Resources:
- https://tensorflow.rstudio.com/install/
- https://tensorflow.rstudio.com/guides/tensorflow/basics
- https://tensorflow.rstudio.com/guides/tensorflow/tensor#basics

Install tenforflow R package, create `TF` reticulate environment, and install python packages within the `TF` environment:

```R
# install R package tensorflow
> install.packages("tensorflow")

# load packages and create TF environment
> library(tensorflow)
> library(reticulate)
> virtualenv_create("TF")

# restart R (Session -> Restart R)

# load packages and install tensorflow in TF environment
> library(reticulate)
> library(tensorflow)
> install_tensorflow(envname="TF", version = "2.14")

# restart R (Session -> Restart R)

# load packages, activate environment, and test GPU
> library(reticulate)
> use_virtualenv("TF")
> library(tensorflow)
> tf$config$get_visible_devices("GPU")
2024-07-01 18:30:47.994659: I tensorflow/core/util/port.cc:111] oneDNN custom operations are on. You may see slightly different numerical results due to floating-point round-off errors from different computation orders. To turn them off, set the environment variable `TF_ENABLE_ONEDNN_OPTS=0`.
2024-07-01 18:30:51.168251: E tensorflow/compiler/xla/stream_executor/cuda/cuda_dnn.cc:9342] Unable to register cuDNN factory: Attempting to register factory for plugin cuDNN when one has already been registered
2024-07-01 18:30:51.168293: E tensorflow/compiler/xla/stream_executor/cuda/cuda_fft.cc:609] Unable to register cuFFT factory: Attempting to register factory for plugin cuFFT when one has already been registered
2024-07-01 18:30:51.185166: E tensorflow/compiler/xla/stream_executor/cuda/cuda_blas.cc:1518] Unable to register cuBLAS factory: Attempting to register factory for plugin cuBLAS when one has already been registered
2024-07-01 18:30:52.702117: I tensorflow/core/platform/cpu_feature_guard.cc:182] This TensorFlow binary is optimized to use available CPU instructions in performance-critical operations.
To enable the following instructions: AVX2 AVX512F AVX512_VNNI FMA, in other operations, rebuild TensorFlow with the appropriate compiler flags.
2024-07-01 18:31:03.751769: W tensorflow/compiler/tf2tensorrt/utils/py_utils.cc:38] TF-TRT Warning: Could not find TensorRT
[[1]]
PhysicalDevice(name='/physical_device:GPU:0', device_type='GPU')
```

Using TensorFlow from R

```R
> library(reticulate)
> use_virtualenv("TF")
> library(tensorflow)
> tf$constant("Hello Tensorflow!")
2024-07-09 17:05:54.925065: I tensorflow/core/common_runtime/gpu/gpu_device.cc:1886] Created device /job:localhost/replica:0/task:0/device:GPU:0 with 79197 MB memory:  -> device: 0, name: NVIDIA A100-SXM4-80GB, pci bus id: 0000:4b:00.0, compute capability: 8.0
tf.Tensor(b'Hello Tensorflow!', shape=(), dtype=string)
```

Run script `/n/holylabs/LABS/rc_admin/Everyone/tensorflow_test.R`:

```bash
paulasan@holygpu8a22103:~$ cat /n/holylabs/LABS/rc_admin/Everyone/tensorflow_test.R
if (length(tf$config$list_physical_devices('GPU')))
  message("TensorFlow **IS** using the GPU") else
  message("TensorFlow **IS NOT** using the GPU")
a <- as_tensor(rbind(c(1.0, 2.0, 3.0), c(4.0, 5.0, 6.0)), dtype=tf$float16)
b <- as_tensor(rbind(c(1.0, 2.0), c(3.0, 4.0), c(5.0, 6.0)), dtype=tf$float16)
print(a)
print(b)
c <- tf$matmul(a, b)
print(c)
```

Output on R console:

```R
> if (length(tf$config$list_physical_devices('GPU')))
+   message("TensorFlow **IS** using the GPU") else
+   message("TensorFlow **IS NOT** using the GPU")
TensorFlow **IS** using the GPU
> a <- as_tensor(rbind(c(1.0, 2.0, 3.0), c(4.0, 5.0, 6.0)), dtype=tf$float16)
> b <- as_tensor(rbind(c(1.0, 2.0), c(3.0, 4.0), c(5.0, 6.0)), dtype=tf$float16)
> print(a)
tf.Tensor(
[[1. 2. 3.]
 [4. 5. 6.]], shape=(2, 3), dtype=float16)
> print(b)
tf.Tensor(
[[1. 2.]
 [3. 4.]
 [5. 6.]], shape=(3, 2), dtype=float16)
> c <- tf$matmul(a, b)
> print(c)
tf.Tensor(
[[22. 28.]
 [49. 64.]], shape=(2, 2), dtype=float16)
```

### Miniconda installation

```R
# install miniconda
> library(reticulate)
> install_miniconda()
> conda_create("r-conda")
+ /n/home_rc/paulasan/.local/share/r-miniconda/bin/conda create --yes --name r-conda 'python=3.10' --quiet -c conda-forge

# Restart R (Session -> Restart R)

# activate environment and install package scipy within environment
> library(reticulate)
> use_condaenv("r-conda")
> conda_install("r-conda", "scipy")
+ /n/home_rc/paulasan/.local/share/r-miniconda/bin/conda install --yes --name r-conda -c conda-forge scipy

# Restart R (Session -> Restart R)

# activate environment and load python package
> library(reticulate)
> use_condaenv("r-conda")
> scipy <- import("scipy")
> py_config()
python:         /n/home_rc/paulasan/.local/share/r-miniconda/envs/r-conda/bin/python
libpython:      /n/home_rc/paulasan/.local/share/r-miniconda/envs/r-conda/lib/libpython3.10.so
pythonhome:     /n/home_rc/paulasan/.local/share/r-miniconda/envs/r-conda:/n/home_rc/paulasan/.local/share/r-miniconda/envs/r-conda
version:        3.10.14 | packaged by conda-forge | (main, Mar 20 2024, 12:45:18) [GCC 12.3.0]
numpy:          /n/home_rc/paulasan/R/ifxrstudio/RELEASE_3_18/python-user-base/lib/python3.10/site-packages/numpy
numpy_version:  1.26.4
scipy:          /n/home_rc/paulasan/.local/share/r-miniconda/envs/r-conda/lib/python3.10/site-packages/scipy

NOTE: Python version was forced by use_python() function
```
