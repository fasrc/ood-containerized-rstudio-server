# Test Singularity Images

This document contains tests used to verify that the Singularity image has the
appropriate settings.

Tests are separated into two categories:

1. Python packages via `pip`: these installs are typically done from the RStudio
   Server terminal.
2. Python packages via `reticulate` R library: these installs are typically done
   from RStudio Server R console/shell.

## Python packages via `pip`

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

   Open the file `/n/holylabs/LABS/rc_admin/Everyone/numpy_test.Rmd`

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
