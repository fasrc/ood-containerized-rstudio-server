# RStudio Server 
<!-- Describe the app from a user's perspective. This is a simplied version of Overview -->
## FASRC users

RStudio Server is an Open OnDemand app that launches RStudio Server as an interactive session on a compute node. 
 
It is designed for researchers who need an Integrated Development Environment (IDE) used to write and run code in the R programming language.

<!-- Link any relevant FASRC docs -->
<!-- ### Using [app name] -->

<!-- Link how to create Sandbox -->
### Sandbox app

For how to create a Sandbox app, see the [Developing your own app using Open
OnDemand](https://docs.rc.fas.harvard.edu/kb/developing-apps-on-ood/)
documentation.

## Appverse overview

> [!NOTE]  
> This section is intended for sys-admins, developers, and power users.

RStudio Server is an Open OnDemand app that launches RStudio Server as an interactive web server session on  HPC clusters. 
 
It is designed for researchers who need an Integrated Development Environment (IDE) used to write and run code in the R programming language.
- Upstream project: [RStudio Server](https://posit.co/download/rstudio-server)

This app uses the Batch Connect `basic` template with Slurm.

- **Batch Connect template:** `basic`
- **Scheduler:** Slurm


## Screenshots

<!-- A screenshot helps deployers verify their installation and helps users understand what they'll get. -->
<!-- Place images in a screenshots/ or docs/ directory. -->

![Rstudio running in browser](images/rstudio_screenshot.png)

## Features

<!-- List the key capabilities specific to THIS OOD app (not the upstream software). -->

- Launches RStudio Server via web server on compute nodes
- Supports GPU and CPU execution
- Configurable partition, memory, CPU cores, GPU cards, and wall time via the launch form
- Additional Slurm options pass-through (long format)
- Reservation support and optional Slurm account
- Email notification on job start
- Containerized via Singularity image


## Requirements

### Compute Node Software

<!-- Batch Connect: What must be installed on the compute nodes where jobs will run? -->
<!-- Passenger: What must be installed on the OOD host? -->
# got to here
$\color{Red}\Huge{\textbf{got to here}}$

- Centralized, read-only virtual environment (using Python 3.12 in this repo at time of writing)
  -  environment has jupyterlab, notebook and nb_conda_kernels installed in it, e.g.:
```
# python3.12 -mvenv /n/sw/jupyterlab/jupyterlab-4.5.0
# . /n/sw/jupyterlab/jupyterlab-4.5.0
(jupyterlab-4.5.0) # pip install --no-cache-dir jupyterlab==4.5.0 notebook==7.5.0 git+https://github.com/anaconda/nb_conda_kernels@2.5.2
```

The CONDA_EXE environment varible must be set to the path of a conda executable in [template/script.sh.erb](template/script.sh.erb).  
nb_conda_kernels will use the conda executable directly to search for additional kernels installed in the users' conda environments, but otherwise the conda environment containing the conda executable will not be used.

### Open OnDemand

- Open OnDemand v3.0+
- [Slurm](https://slurm.schedmd.com/) job scheduler


## App Installation

Please see the [References section](#software-installation) below for instructions on how to install the software that is launched by this app.

### 1. Clone the repository

```bash
# Batch Connect / Passenger apps:
cd /var/www/ood/apps/sys

git clone https://github.com/fasrc/ood-jupyter.git
cd ood-jupyter

```

### 2. Configure for your site

<!-- Point deployers to the ONE place they need to edit. -->
#### form.yml.erb Attributes

Edit `form.yml.erb` and update these values for your cluster (in order as they
appear at the bottom of [form.yml.erb](form.yml.erb)):

| Attribute | Description | FASRC settings | Change to |
|-----------|-------------|---------| -----------|
| `cluster` | Target cluster ID | `odyssey3` | Your cluster name |
| `bc_queue` | Default scheduler partition | user-defined; default `shared` | Your preferred partition |
| `jupyterlab_switch` | Start Jupterlab instead of Notebook | `1` | Your preference |
| `custom_memory_per_node` | Memory per node (GB) | user-defined; default: `4` | Your preferred memory allocation |
| `custom_num_cores` | Number of cores | user-defined; default `1` | Your preferred default number of cores |
| `custom_num_gpus` | Number of GPUs | user-defined; default `0` | Your preferred default number of GPUs |
| `custom_time` | Maximum wall time (HH:MM:SS) | user-defined; default `04:00:00` | Your preferred default time |
| `working_folder` | **Optional** Override default (homedir) location to launch Jupyter Server in | user-defined | |
| `envscript` | **Optional** Script to run before starting Jupyter |user-defined | |
| `modules` | **Optional** Additional modules to load before starting Jupyter |user-defined | |
| `custom_reservation` | **Optional** Slurm reservation `--reservation` | user-defined | |
| `extra_slurm` | **Optional** Extra slurm option (long-format) | user-defined | Remove if using aother scheduler |
| `bc_account` | **Optional** Alternate slurm account to charge instead of user's primary group | user-defined | Remove if using aother scheduler |
| `custom_email_address` | **Optional** email address for status notificationl used along with `bc_email_on_started` | user-defined | |
| `bc_email_on_started` | **Optional** sends email to `custom_email_address` when job starts | user-defined | |

#### manifest.yml Attributes

Edit `manifest.yml` and update these values for your organization:

| Attribute | Change to |
|-----------|-----------|
| `description` | Your cluster and your documentation |

<!-- Passenger apps: describe any config files, environment setup, or bundle install steps. -->
<!-- If there are additional config files, list them too. -->

<!-- Passenger: -->
<!-- Restart the app from the OOD developer dashboard, or restart the PUN. Visit your OOD dashboard and navigate to [App URL]. -->


<!-- Document ALL site-specific values and where they live. -->
<!-- This is the most important section for deployers at other sites. -->

<!-- Batch Connect apps: document form.yml attributes -->
<!-- Passenger apps: document config files, environment variables, or database setup -->


### 3. Verify

<!-- Batch Connect: -->
No OOD restart is needed (Batch Connect apps are detected automatically). Visit your OOD dashboard and look for **Jupyter** under **Interactive Apps > Web Apps**.


## Troubleshooting

### Job starts but app doesn't appear (Batch Connect)

1. Check the job's `output.log` in `~/.ondemand/data/sys/YOUR-APP/`
2. Verify the module loads correctly: `module load software/1.0`

### "Module not found" error

The module name in `form.yml` doesn't match your system. Run `module spider software` to find the correct name and update the `modules` attribute.

### Connection timeout

The app may need more time to start. Increase the connection timeout or check that the compute node can open the required port.

<!-- Add real issues you've encountered during testing. -->

### Jupyter notebook VDI session is terminated right after it starts
This problem is common when there is a `conda initialize` section in the user's .bashrc file located in their home directory. The `conda initialize` section was added when, at some point, the user ran the command `conda init`. Instead of using conda init, we recommend `source activate environment_name`.  

To solve this problem, delete or comment out the `conda initialize` section of your .bashrc and create a new Jupyter notebook VDI session.

### Jupyter notebook/JupyterLab VDI session starts but does not display a ‘Connect to Jupyter’ button
If this problem occurs, you may see an error, jupyter: command not found, in the session's `output.log`.  
To solve this problem, delete the line auto_activate_base: false in the file `~/.condarc`.
## Testing

<!-- Where has this app been deployed and verified? -->

| Site | Operating System* | OOD Version | Scheduler | Status |
|------|------------------|-------------|-----------|--------|
| FASRC | Rocky 8.10 | 3.1 | Slurm 25.11 | Tested |
| FASRC | Rocky 8.10 | 4.0 | Slurm 25.11 | Tested |
| FASRC | Rocky 8.10 | 4.1 | Slurm 25.11 | Tested |

> [!NOTE]
> \*Operating system of compute nodes

<!-- How can a deployer verify it works? -->

To verify your installation:

1. Launch the app from the OOD dashboard with default settings
2. Confirm the application loads in the browser

## Known Limitations

<!-- Be honest about what doesn't work or hasn't been tested. -->

- Multi-node jobs are not supported
- Only tested on RHEL 8; may not work on other distributions

## Contributing

Contributions are welcome. To contribute:

1. Fork this repository
2. Create a feature branch (`git checkout -b feature/my-improvement`)
3. Submit a pull request with a description of your changes

For bugs or feature requests, [open an issue](https://github.com/fasrc/ood-jupyter/issues).

This app is part of the [OOD Appverse](https://ondemand.connectci.org/affinity-groups/ood-appverse). Join the [Appverse Affinity Group](https://ondemand.connectci.org/affinity-groups/ood-appverse) to connect with other contributors.

## References

<!-- Credit upstream projects and any code you borrowed. -->

- [Jupyter](https://jupyter.org/)— the application launched by this OOD app
- [Open OnDemand](https://openondemand.org/) — the HPC portal framework

### Software Installation

* [Jupyter Installation Guide](https://jupyter.org/install)

## License

[MIT License](LICENSE.txt)

## Acknowledgments

This work is supported by [FASRC](https://www.rc.fas.harvard.edu) at Harvard
Univesity.


------

# RStudio Server

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

