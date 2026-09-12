# Download manifest

One row per file. `url` is filled in when the current download location is
located on data.ed.gov, nces.ed.gov, census.gov, or bls.gov. `sha256` and
`downloaded_utc` are written by `R/02_download.R` on first download and
verified on every later run. A blank `url` means the file is **not published**:
the row records that the study looked for it and the source has none. Six rows
are in that state, all listed under the graduation bullet below;
`R/02_download.R` skips them and every other row carries a checksum.

Files are archived as the source publishes them, so `filename` carries the
source format: CCD rows are the NCES tab-delimited `.zip`, SAIPE rows are the
fixed-width `ussdYY.txt`, F-33 rows are the comma-delimited `elsecYY.txt`
(saved as `.csv`; FY2022 is the exception noted below).

CPI: BLS blocks scripted requests, so `cpi/cuur0000sa0.xlsx` was saved from
the data viewer by hand. `cpi/cuur0000sa0.csv` (columns `series_id, year,
month, value`) is derived from it with
`Rscript -e "source('R/functions/cpi.R'); write.csv(cpi_from_bls_xlsx('data/raw/cpi/cuur0000sa0.xlsx'), 'data/raw/cpi/cuur0000sa0.csv', row.names = FALSE)"`.
Both rows carry a checksum. The download script never fetches either, because
both files exist.

ED published no EDFacts assessment participation files before 2012-13, so the
manifest has no participation rows for end years 2010-2012. Design v17
retains those years without the participation test (Section 5).

Rows are the stage-1 set (school years ending 2010–2013) plus the stage-2 set
added on 2026-09-12, once the registration was filed and `data/stage.txt`
became `2`. Dataset names beginning with `edfacts_` are outcome files and are
subject to the stage gate.

Stage 2 covers end years 2014 through the registration end year 2021 for
EDFacts achievement and participation, 2014 through 2024 for CCD, SAIPE and
F-33, and 2011 through 2024 for the EDFacts adjusted cohort graduation rate
files behind the secondary outcome (Section 6). Notes on where each stage-2
row points:

- **EDFacts, end year 2019 (SY2018-19).** The legacy `www.ed.gov/sites/ed/…/
  data-files/` names return 404 for that school year, so its four assessment
  files come from the ED Data Library (`eddataexpress.ed.gov`) instead. Those
  are zipped CSVs in the ED Data Library's long layout (one row per
  LEA-subgroup-measure, columns `School Year, State, NCES LEA ID, …, Value,
  Denominator, Subgroup, Age/Grade, Academic Subject`), not the wide layout of
  the legacy files. Every other achievement and participation row, 2014–2018
  and 2021, is the legacy ed.gov CSV.
- **End year 2020 (SY2019-20).** No EDFacts assessment file of any kind was
  published, and design Section 3 excludes that school year from the
  achievement gaps, so the manifest has no achievement or participation row for
  it. The graduation file for that year does exist and is archived: the
  exclusion covers the waived assessments only (author, 2026-09-12;
  `docs/deviations.md`, Section 3).
- **Graduation rate (`edfacts_acgr_lea`).** Legacy ed.gov per-year CSVs for end
  years 2011–2018; ED Data Library zips for 2019, 2020 and 2021. **Not
  published for end years 2022, 2023 or 2024.** Checked 2026-09-12: the ED Data
  Library holds state-level graduation files for 2022 and 2023 and none for
  2024, and the legacy names 404 for all three. A state-level rate cannot form
  a within-district gap, so there is no substitute. These six rows — three
  `edfacts_acgr_lea` and the three matching `edfacts_acgr_docs` — are the
  manifest's only blank-url rows, and they stay blank: they are a record that
  no LEA file exists, not a download still to be made. The graduation window is
  therefore end years 2011 through 2021 (author, 2026-09-12;
  `docs/deviations.md`, Section 3), with 2020 retained for this outcome alone.
- **CCD.** End year 2014 is the last combined universe file (`ag131a_supp`,
  `sc132a`). From 2014-15 the nonfiscal survey is split, so each later year has
  three rows: the LEA Directory file (`ccd_lea_029_*`), the school Membership
  file (`ccd_sch_052_*`) and, under `ccd_lunch_program`, the school Lunch
  Program Eligibility file (`ccd_sch_033_*`) that carries the CEP field
  (Section 2.5 of `docs/data_acquisition.md`). Each url is the newest release
  of that year listed by the NCES file API, flat text where the release offers
  a format choice.
- **F-33, FY2022.** `elsec22.txt` holds only 1,730 of the 14,106 unit records
  Census published for that fiscal year (17 Alabama systems against 138 in the
  companion flag file `elsec22f.txt`), so the FY2022 row archives
  `elsec22.xlsx`, which carries all 14,106. It is the only F-33 row that is not
  the comma-delimited text file.

Deposits
Stage 1: https://doi.org/10.17605/OSF.IO/6FDVY, deposited 2026-09-11, containing stage1_raw.zip
404a4bcc4f67d3bb61dee069771525613061c8765bb4d7b107a38b82474a78c6

Stage 2: https://doi.org/10.17605/OSF.IO/6FDVY, deposited 2026-09-11
d51b0f3ce5ebc9fbbda3dfab33561a48f832d0d97ff3da91ec12354fb81cbc41