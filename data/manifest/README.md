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
`R/02_download.R` fetches only the stage 1 rows (`STAGE1_ROWS` in
`R/functions/stage.R`): the EDFacts high school assessment files for end years
2010-2013, the participation files for 2013 and their documentation; the CCD
files for end years 2007-2013; SAIPE income year 2009; and F-33 fiscal years
2010-2013. The CPI series, the graduation, SEDA and report-card files and
every later year are stage 2. At stage 2 every row is allowed.

## Rows a reader fetches by hand

A blank `url` means there is no address to fetch from. The script still
verifies the checksum of such a file once it is in `data/raw/`.

- Report-card files served only through an interactive reporting tool are
  exported through a browser; each row's `notes` gives the steps.
- Some sites refuse scripted requests (ed.gov for every EDFacts file, and
  the agencies of AZ, CO, DC, KY, MN, NH, NM and VA);
  those files are downloaded through a browser and moved into place.
- The CPI workbook is saved from the BLS data viewer. The CSV beside it is
  derived with `cpi_from_bls_xlsx()` in `R/functions/cpi.R`.
- New York's report-card tables are exported from the Access database in each
  zip by `R/02a_ny_access_export.R` (run in the container with mdbtools).

## File notes

- EDFacts end year 2019: both ED's release and the `*_edc_archive` rows
  (Education Data Center EDFacts archive) are listed. Step 3 reads the copy
  that covers the 50 states and DC, ED's release first, and logs the choice.
- No EDFacts assessment file exists for end year 2020; the graduation file for
  that year does.
- F-33: the text release of each fiscal year is read unless the spreadsheet
  release of that year holds more records (both are listed for 2022); the
  choice is written to `f33_sources.csv`.
- CCD school universe 2006-07 is published as three fixed-width files with a
  separate record layout row.

## SEDA

The SEDA rows point to the Stanford Digital Repository. Release 2025.1 is read
only if the 2025.2 long file lacks end years 2009-2019; step 9 logs the
release read. The files are used
under the SEDA data use agreement and are never committed or deposited, in
full or in part. A reader must accept the agreement at edopportunity.org and
download the files from the addresses in the manifest.
