# Download manifest

One row per file. `url` is filled in when the current download location is
located on data.ed.gov, nces.ed.gov, census.gov, bls.gov, or, for the Run 2
SEDA rows, stacks.stanford.edu. `sha256` and
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
- **EDFacts, end year 2019: the ED release is truncated; the files used come
  from an archive (2026-09-12).** The four ED Data Library files above hold
  only Alabama through North Dakota, BIE and Puerto Rico: the
  `_LEA_part_2_of_2_OH_to_WY.csv` member carries 96 Puerto Rico rows, and the
  README's item count (1,391,420) exceeds the 937,216 rows present, so Ohio,
  Oklahoma, Oregon, Pennsylvania, Rhode Island, South Carolina, South Dakota,
  Tennessee, Texas, Utah, Vermont, Virginia, Washington, West Virginia,
  Wisconsin and Wyoming are missing. A fresh download on 2026-09-12 was
  byte-identical to the archived zips. The four rows
  `edfacts_*_edc_archive` archive the same school year from the Education
  Data Center EDFacts archive (`https://www.eddatacenter.org/edfacts`, files
  on `storage.googleapis.com/edc-education-exports/edfacts/`, object
  last-modified 2025-03-26): ED's legacy long-layout files
  `{math,rla}-{achievement,participation}-lea-sy2018-19-long.csv`
  (`DATE_CUR` 13AUG20; columns `SCHOOL_YEAR, STNAM, FIPST, LEAID, ST_LEAID,
  LEANM, SUBJECT, GRADE, CATEGORY, DATE_CUR, NUMVALID|NUMPART,
  PCTPROF|PCTPART`), which cover all 50 states and DC. Checked against the
  ED release for the 36 jurisdictions both carry, high school band, subgroups
  ALL, MWH, MBL, MHI and ECD: every reported percentage is identical
  (154,444 cells over the four files); the only differences are cells ED
  writes with count `0` and value `.` where the archive leaves the count
  blank, and neither passes rule 3 or rule 4. The loader reads the archive
  rows for end year 2019; the ED Data Library rows stay in the manifest as
  the record of the truncated release. The Urban Institute Education Data
  Portal (`school-districts/edfacts/assessments`, year 2018) also carries the
  sixteen states, but in its own recoded layout, so it was not used.
  (`docs/deviations.md`, 2026-09-12.)
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
  Program Eligibility file (`ccd_sch_033_*`). Each url is the newest release
  of that year listed by the NCES file API, flat text where the release offers
  a format choice.
- **CCD school Characteristics (`ccd_school_characteristics`), end years
  2015-2021**, added 2026-09-12. This is the file that carries the CEP field
  `NSLPSTATUS`, not the Lunch Program Eligibility file, whose `LUNCH_PROGRAM`
  field has no CEP value in any year (Section 2.5 of
  `docs/data_acquisition.md`). End year 2014 needs no row: the combined school
  universe file already archived under `ccd_membership` 2014 (`sc132a`) carries
  `NSLPSTATUS`. The rows stop at 2021, the registration end year, because no
  later year enters either outcome.
- **CCD school universe, end years 2007-2009** (`ccd_membership`, added
  2026-09-14), for the Lee bounds' grade 9 membership three years before each
  tested year (`docs/deviations.md`, 2026-09-14). 2007-08 (`sc071b`, v.1b) and
  2008-09 (`sc081b`, v.1b) are single tab-delimited national files. 2006-07
  (`sc061c`, v.1c) is published only as three fixed-width files by state group
  (`ai`, `kn`, `ow`), so it has three rows, plus a `ccd_membership_layout` row
  for its NCES record layout `psu061clay.txt`, which gives the field positions.
  Not yet in an OSF deposit.
- **SEDA 2025.2 (`seda_admindist_long_cs`, `seda_codebook_admindist`,
  `seda_documentation`), added 2026-09-15.** The first Run 2 rows
  (`docs/design_extension.md`, Section 4; `data/stage_run2.txt` = 2). Source:
  the Stanford Digital Repository, DOI 10.25740/np279jm6134 (PURL
  `https://purl.stanford.edu/np279jm6134`), release SEDA 2025.2, which
  supersedes 2025.1. Each row's url is the repository's direct file path
  `https://stacks.stanford.edu/file/np279jm6134/<file name>`, recorded in
  `docs/recon_run2.md`. The three files are the administrative-district
  cohort-standardized long file (`seda_admindist_long_cs_2025.2.csv`), its
  codebook (`seda_codebook_admindist_2025.2.xlsx`) and the release
  documentation (`SEDA_documentation_2025.2.pdf`). The author accepted the SEDA
  data use agreement at edopportunity.org on 2026-09-01, before the download
  (`docs/decision_log_run2.md`). The agreement forbids publishing the files in
  full or in part, so they are never deposited; see the next section. They have
  no `sy_end`: one file covers every SEDA year (school years ending 2009-2019
  and 2022-2025), as the two CPI rows cover every month. They are not EDFacts
  outcome files, so the Run 1 stage gate in `R/02_download.R` does not apply to
  them.
- **F-33, FY2022.** `elsec22.txt` holds only 1,730 of the 14,106 unit records
  Census published for that fiscal year (17 Alabama systems against 138 in the
  companion flag file `elsec22f.txt`), so the FY2022 row archives
  `elsec22.xlsx`, which carries all 14,106. It is the only F-33 row that is not
  the comma-delimited text file.

Never deposited

These paths are not uploaded to OSF, in any deposit, in full or in part. Their
manifest rows carry the url and the checksum, which is what a reader needs to
obtain the same bytes from the source under the source's own terms.

- `data/raw/seda/` — the SEDA 2025.2 files above, and any file derived from them
  that reproduces their district-level estimates. The SEDA data use agreement
  the author accepted on 2026-09-01 forbids publishing them in full or in part
  (`docs/design_extension.md`, Section 4). A reader must accept the same
  agreement at edopportunity.org and download the files from DOI
  10.25740/np279jm6134. Run 2's OSF deposits hold the report-card data, the
  manifest, the checksums and the outputs, not these files.

Deposits
Stage 1: https://doi.org/10.17605/OSF.IO/6FDVY, deposited 2026-09-11, containing stage1_raw.zip
404a4bcc4f67d3bb61dee069771525613061c8765bb4d7b107a38b82474a78c6

Stage 2: https://doi.org/10.17605/OSF.IO/6FDVY, deposited 2026-09-11
d51b0f3ce5ebc9fbbda3dfab33561a48f832d0d97ff3da91ec12354fb81cbc41

Stage 2 supplement: added to the stage 2 component on 2026-09-13, containing stage2_supplement_2018-19.zip with the four SY 2018-19 achievement and participation files from the Education Data Center EDFacts archive, used in place of ED's truncated release

859709c1a787e448b03774723d7400233bb93b3bf41e3c4478137e9297ee7ecb
Stage 2 CCD supplement: added to the stage 2 component on 2026-09-14, containing the CCD school universe files for school years ending 2007, 2008, and 2009 used for the Lee-bounds tested shares
b3a3cadb7279b870025d02e48be55e83d9e8bd0b010cbfe327e92a06bccc58d1

Outputs
run 1 Outputs
c90871524bf5f3e8b8a281f5ab77711b1e31d56d1433ee62121f046832514d79