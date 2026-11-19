# Download manifest

`download_manifest.csv` lists every file the study reads, one row per file.

Columns: `dataset`, `sy_end` (school year by its end year; blank for files that
cover every year), `url`, `filename` (path under `data/raw/`), `sha256`,
`downloaded_utc`, `state`, `page_url`, `status`, `source` and `notes`.

`sha256` and `downloaded_utc` are blank until `R/02_download.R` fetches the
file. The script records both on first download and verifies the checksum on
every later run, so any change to an archived file stops the run.

`status` is blank for a file to be downloaded. Two values record a source
that has no usable file:

- `not_published`: the publisher issued no such file (the EDFacts LEA
  graduation files for end years 2022-2024).
- `unavailable`: the source publishes nothing that meets the matching rule
  for that state-year (Idaho's report-card export, 2022-2025).

## Stage gate

`data/stage.txt` reads `1` until the registration is filed. At stage 1,
`R/02_download.R` fetches only the rows the power simulation needs
(`STAGE1_ROWS` in `R/functions/stage.R`): the EDFacts high school assessment
files for end years 2010-2013, the participation files for 2013, their
documentation, the CCD LEA directories for 2010-2013, the 2009-10 CCD school
membership file and the 2009 SAIPE file. At stage 2 every row is allowed.

## Rows a reader fetches by hand

A blank `url` means there is no address to fetch from. The script still
verifies the checksum of such a file once it is in `data/raw/`.

- Report-card files served only through an interactive reporting tool are
  exported through a browser; each row's `notes` gives the steps.
- Some agencies refuse scripted requests (AZ, CO, DC, KY, MN, NH, NM, VA);
  those files are downloaded through a browser and moved into place.
- The CPI workbook is saved from the BLS data viewer. The CSV beside it is
  derived with `cpi_from_bls_xlsx()` in `R/functions/cpi.R`.
- New York's report-card tables are exported from the Access database in each
  zip by `R/02a_ny_access_export.R` (run in the container with mdbtools).

## File notes

- EDFacts end year 2019: the ED Data Library release is truncated, so the
  `*_edc_archive` rows (Education Data Center EDFacts archive) are read for
  that year.
- No EDFacts assessment file exists for end year 2020; the graduation file for
  that year does.
- F-33 fiscal year 2022 is archived as `elsec22.xlsx`, the text file being
  incomplete.
- CCD school universe 2006-07 is published as three fixed-width files with a
  separate record layout row.

## SEDA

The SEDA rows point to the Stanford Digital Repository. The files are used
under the SEDA data use agreement and are never committed or deposited, in
full or in part. A reader must accept the agreement at edopportunity.org and
download the files from the addresses in the manifest.
