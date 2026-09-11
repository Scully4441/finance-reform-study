# Download manifest

One row per file. `url` is filled in when the current download location is
located on data.ed.gov, nces.ed.gov, census.gov, or bls.gov. `sha256` and
`downloaded_utc` are written by `R/02_download.R` on first download and
verified on every later run.

Files are archived as the source publishes them, so `filename` carries the
source format: CCD rows are the NCES tab-delimited `.zip`, SAIPE rows are the
fixed-width `ussdYY.txt`, F-33 rows are the comma-delimited `elsecYY.txt`
(saved as `.csv`).

CPI: BLS blocks scripted requests, so `cpi/cuur0000sa0.xlsx` was saved from
the data viewer by hand. `cpi/cuur0000sa0.csv` (columns `series_id, year,
month, value`) is derived from it with
`Rscript -e "source('R/functions/cpi.R'); write.csv(cpi_from_bls_xlsx('data/raw/cpi/cuur0000sa0.xlsx'), 'data/raw/cpi/cuur0000sa0.csv', row.names = FALSE)"`.
Both rows carry a checksum. The download script never fetches either, because
both files exist.

ED published no EDFacts assessment participation files before 2012-13, so the
manifest has no participation rows for end years 2010-2012. Design v17
retains those years without the participation test (Section 5).

Rows listed now are the stage-1 set (school years ending 2010–2013). Stage-2
rows for later years are added after the OSF registration, when
`data/stage.txt` becomes `2`. Dataset names beginning with `edfacts_` are
outcome files and are subject to the stage gate.
