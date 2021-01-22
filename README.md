<!-- Add a project state badge
See https://github.com/BCDevExchange/Our-Project-Docs/blob/master/discussion/projectstates.md
If you have bcgovr installed and you use RStudio, click the 'Insert BCDevex Badge' Addin. -->

MD10A1\_MSLP\_LDA
=================

### Usage

This repository contains the scripts used in the analysis
*Classification of Clustered Snow Off Dates Over British Columbia,
Canada, from Mean Sea Level Pressure* (Gleason et al., 2020). In
addition, a Docker image is provided for enabling annual predictions of
the BC Snow Off Clusters.

There are 7 core scripts that are required for the analysis, they need
to be run in order:

-   DL\_Fall\_ERA5\_MSLP.py
-   1\_SDOFF\_CLUSTER.R
-   2\_FALL\_ERA5\_PCA.R
-   3\_SDOFF\_MSLP\_LDA.R
-   4\_TeleCorr.R
-   DL\_Fall\_ERA5\_MSLP\_annual.py
-   5\_MAKE\_LDA\_PREDICTION.R

Note these scripts are provided for transparency, the data required to
run them is not hosted on this repository because of storage
constraints, however, we would be happy to provide these data by
request. Please see section about running Docker image for making annual
predictions.

#### Docker Example

Annual predictions of the gridded Snow Off Clusters can be generated
using the Docker image *huntgdok/bc\_lda\_sdoff*. This Docker image
simplifies running the *DL\_Fall\_ERA5\_MSLP\_annual.py* and
*5\_MAKE\_LDA\_PREDICTION.R* scripts and only requires the user provide
their CDC credentials. Assuming Docker is installed locally, the image
can be obtained using the following Docker command:

``` bash
docker pull huntgdok/bc_lda_sdoff:latest
```

Once the image is in place, the follwing steps must be completed before
running the Docker image. First, the users Climate Data Store
Application Program Interface credentials (.cdsapirc) file must be
copied into a directory named *userdata* on the users local machine,
e.g.:

``` bash
cd C:/Users/user/Desktop
mkdir userdata
cd userdata
cp C:/Users/user/.cdsapirc .
```

The Docker image can then be run by attaching the *userdata* directory
with the volume flag *-v*. In addition, the user needs to provide the
year (corresponding to fall) to make a prediction by specifying YEAR in
the global environment *-e*, e.g., to make a prediction for hydrologic
year 2020:

``` bash
docker run -e YEAR=2020 -v C:/Users/user/Desktop/userdata:/home/userdata huntgdok/bc_lda_sdoff:latest
```

The user may see various messages and warnings, of these some can be
ignored including *getProjectionRef…* and *…Ran out of file reading
SECT0*. On a typical laptop computer the prediction should take 5-10
minutes to run so please be patient. Upon completion, the ERA5 mean sea
level pressure GRIB file and the prediction output CSV will should
appear in the *userdata* directory as *fall\_era5\_download.grib* and
*BC\_SDoff\_Prediction.csv* respectively.

### Project Status

[![img](https://img.shields.io/badge/Lifecycle-Maturing-007EC6)](https://github.com/bcgov/repomountie/blob/master/doc/lifecycle-badges.md)

### Getting Help or Reporting an Issue

To report bugs/issues/feature requests, please file an
[issue](https://github.com/bcgov/MD10A1_MSLP_LDA/issues/).

### How to Contribute

If you would like to contribute, please see our
[CONTRIBUTING](CONTRIBUTING.md) guidelines.

Please note that this project is released with a [Contributor Code of
Conduct](CODE_OF_CONDUCT.md). By participating in this project you agree
to abide by its terms.

### License

    Copyright 2021 Province of British Columbia

    Licensed under the Apache License, Version 2.0 (the &quot;License&quot;);
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an &quot;AS IS&quot; BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and limitations under the License.

------------------------------------------------------------------------

*This project was created using the
[bcgovr](https://github.com/bcgov/bcgovr) package.*
