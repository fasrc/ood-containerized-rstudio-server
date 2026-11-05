commit 583cbdad2cf11fac963c15db985ae6440367cec7
Author: Paula C. Sanematsu <103142727+paulasanematsu@users.noreply.github.com>
Date:   Wed Apr 1 16:07:10 2026 -0400

    Rectify differences between main and fasse branches (#3)

diff --git a/Singularity/test_sing_images.md b/Singularity/test_sing_images.md
index 7d3d98a..767769e 100644
--- a/Singularity/test_sing_images.md
+++ b/Singularity/test_sing_images.md
@@ -16,7 +16,7 @@ Tests are separated into two categories:
 Directories to delete to "clean" your Python/R environment:
 
 - `~/.local/`
-- ` ~/R/ifxrstudio/RELEASE_<version>/`
+- `~/R/ifxrstudio/RELEASE_<version>/`
 - `~/.virtualenvs/`
 
 Launch OOD RStudio Server with:
@@ -373,6 +373,8 @@ tf.Tensor(
 > use_condaenv("r-conda")
 > conda_install("r-conda", "scipy")
 + /n/home_rc/paulasan/.local/share/r-miniconda/bin/conda install --yes --name r-conda -c conda-forge scipy
+> conda_install("r-conda", "pandas")
++ /n/home_rc/paulasan/.local/share/r-miniconda/bin/conda install --yes --name r-conda -c conda-forge pandas
 
 # Restart R (Session -> Restart R) RELEASE <= 3.19
 
