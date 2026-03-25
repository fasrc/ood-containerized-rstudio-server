# RStudio (Rocker)

## Overview

An [Open OnDemand](https://openondemand.org/) Batch Connect app that launches
[RStudio Server](https://posit.co/products/open-source/rstudio-server/) in a
Singularity container on a compute node. The containers are based on
[Rocker](https://rocker-project.org/) /
[Bioconductor](https://www.bioconductor.org) images and provide a
curated R environment including geospatial and Bioconductor packages.

## FASRC Cannon 

If you are running this app on FASRC's Cannon cluster, you can
simply clone to `~/.fasrcood/dev` and it will show in your [Sandbox
Apps](https://rcood.rc.fas.harvard.edu/pun/sys/dashboard/admin/dev/products). 

## Site-specific modifications

If you wish to use this app in a different cluster, some files need to edited to
conform to your site's OOD implementation. All necessary and potential
modifications are commented with a `site-specific` tag. For example, the file
`form.yml` has for slurm partition:

```
  bc_queue:
# site-specific: change default partition
    value: "test"
```

List of files to edit:

1. [`form.yml`](form.yml)
2. [`manifest.yml`](manifest.yml)
3. [`template/before.sh.erb`](template/before.sh.erb)
4. [`template/script.sh.erb`](template/script.sh.erb)

This app assumes the cluster uses slurm as the scheduler. If you use a different
scheduler, you wil likely need to modify other files.

## Singularity containers

You can build the Singularity containers using the Singularity definition files
provided in this repository:

- [RELEASE 3.20](Singularity/release_3_20.def)
- [RELEASE 3.19](Singularity/release_3_19.def)
- [RELEASE 3.18](Singularity/release_3_18.def)

> [!IMPORTANT]
> **GPU support**
> Releases 3.15 through 3.20 come from [Bioconductor
ml-verse](https://github.com/Bioconductor/bioconductor_docker/pkgs/container/ml-verse)
> and may have GPU support. 

### Testing

Before deploying a new release, perform the tests in [Singularity/test_sing_images](Singularity/test_sing_images.md).

## R packages

### `R_LIBS_USER`

`R_LIBS_USER` is set to `$HOME/R/ifxrstudio:${TAG}`, e.g. `RELEASE_3_13`

### R packages pinned version

R packages in RStudio Server are tied to a specific CRAN version.

FASRC serves a very wide range of researchers that use RStudio, from geospacial
to informatics as well as a big group in the social sciences. This means that
we have to be able to install many different R packages. When we install R
packages directly in the cluster's OS, we have to select the right compilers,
libraries, etc. This proved to be very time consuming for us and made users
very frustrated.

Our solution was to develop a Singularity container with RStudio Server and many
of the packages precompiled to ensure an easy installation (for most cases) for
users. To implement this, we use the [rocker project](https://github.com/rocker-org/rocker-versioned2). The upstream (rocker) project
pins to particular date for all R versions (except the latest version), and our
(Singularity) images inherit that pinning; e.g. see this [dockerfile](
https://github.com/rocker-org/rocker-versioned2/blob/23b6961dcc187b7290b35ae4434180dfb1fa7f24/dockerfiles/r-ver_4.2.1.Dockerfile#L16).

The rationale for this is described a bit more in this [GitHub
issue](https://github.com/rocker-org/rocker-versioned2/issues/201) which links
to this page with the list of [pinned CRAN
versions](https://github.com/rocker-org/rocker-versioned2/wiki/Versions).

On release 3.16, Nathan Weeks changed to the [Bioconductor
ml-verse](https://github.com/Bioconductor/bioconductor_docker/pkgs/container/ml-verse)
project to support GPUs. The same pinning is ensured because
`bioconductor_docker:ml-verse` uses the upstream `rocker/ml-verse` base image --
e.g., see this
[dockerfile](https://github.com/rocker-org/rocker-versioned2/blob/f7161ec6d4310518df14a5ab47fdde098c8764fb/dockerfiles/ml-verse_4.3.3.Dockerfile#L10)
for release 3.18.

However, the pinned date drawback is that newer packages (installed from
source) may depend on newer versions of CRAN packages than exist at the pinned
date.

After implementing this approach of using precompiled binaries packages, we
noticed a big improvement for the majority of users and a considerable decrease
in tickets requesting help with R packages. Unfortunately, there will always be
edge cases. But, overall, this pinned version has worked well.

- R_LIBS_USER is set to $HOME/R/ifxrstudio:${TAG}{ (e.g., RELEASE_3_13)
