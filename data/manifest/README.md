# Download manifest

One row per file. `url` is filled in when the current download location is
located on data.ed.gov, nces.ed.gov, census.gov, or bls.gov. `sha256` and
`downloaded_utc` are written by `R/02_download.R` on first download and
verified on every later run.

Rows listed now are the stage-1 set (school years ending 2010–2013). Stage-2
rows for later years are added after the OSF registration, when
`data/stage.txt` becomes `2`. Dataset names beginning with `edfacts_` are
outcome files and are subject to the stage gate.
