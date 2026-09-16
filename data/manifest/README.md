# Download manifest

One row per file. Columns: `dataset`, `sy_end`, `url`, `filename`, `sha256`,
`downloaded_utc`, and, added with the Run 2 report-card rows on 2026-09-15,
`state`, `page_url`, `status`, `source` and `notes`. The five added columns are
blank on every row written before that date. `sha256` and `downloaded_utc` are
written by `R/02_download.R` on first download and verified on every later run.

`status` says what the study holds for the row:

- `archived` — the file is in `data/raw/` under `filename` and carries a
  checksum. 391 rows.
- `hand_download` — the source publishes the data but not as a fetchable file,
  so it is still to be exported by hand. `url`, `filename`, `sha256` and
  `downloaded_utc` are blank and `notes` carries the steps. 0 rows: the 37 Run 2
  report-card rows that carried this status were exported or requested on
  2026-09-15 and 2026-09-16 and are now `archived` or `unavailable`.
- `requested` — added 2026-09-16. The source builds the file on request and
  sends it, rather than serving it, so there is nothing to fetch and nothing to
  export: the request has been submitted and the file has not arrived. `url`,
  `filename`, `sha256` and `downloaded_utc` are blank and `notes` carries the
  request as submitted. 0 rows: MI 2023-2025, the three rows that carried it,
  were delivered and archived on 2026-09-16, and the eight Michigan SAT
  cross-tabulated requests arrived with them.
- `unavailable` — added 2026-09-16. The source was worked through and publishes
  nothing that meets the design's matching rule for that state-year, so no file
  can be archived. `url`, `filename`, `sha256` and `downloaded_utc` are blank and
  `notes` carries what was found and what was rejected. 4 rows, ID 2022-2025.
  Distinct from `not_published`, which records a file the publisher never issued
  at all rather than a source that fails the matching rule.
- `not_published` — the source has no such file at all: the row records that the
  study looked and found none. 6 rows, all listed under the graduation bullet
  below. They carry a placeholder `filename` and no checksum.

A blank `url` therefore means only that there is no url to fetch from; `status`
says which of the reasons applies. `R/02_download.R` checksums every row whose
`filename` names a file that is in `data/raw/`, whether or not the row has a
`url`, and verifies it against `sha256` when one is recorded; a blank `url` is
not a reason to skip a row, since the Run 2 report-card files are exported by
hand and have no url. It skips a row with a blank `filename`, and a row whose
file is not in `data/raw/` and has no `url` to fetch it from. Run 1 rows take
their `url` from data.ed.gov,
nces.ed.gov, census.gov or bls.gov, the Run 2 SEDA rows from
stacks.stanford.edu, and the Run 2 report-card rows from the publishing state
education agency, recorded per row in `page_url` or `source`.

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
- **High school report cards (`hs_reportcard_*`), end years 2022-2025**, added
  2026-09-15. The second set of Run 2 rows (`docs/design_extension.md`,
  Section 4; `data/stage_run2.txt` = 2), one state education agency file per
  state-year-subject, archived under `data/raw/hs_reportcards/<STATE>/`. 233
  rows over 41 states and DC. A state whose agency publishes mathematics and
  reading separately, or several high school tests, has one row per file, so
  rows outnumber state-years: `hs_reportcard_al_math` and `hs_reportcard_al_rla`,
  the four `hs_reportcard_nj_*` tests, `hs_reportcard_ca_entities` beside
  `hs_reportcard_ca`, and so on. `state` carries the postal code, `page_url` or
  `source` the publishing page, and `notes` the per-file layout the Section 6
  loaders need: which column or row holds the district, the subgroup labels, the
  grade or course that matches the state's EDFacts high school result, and the
  suppression symbols. Coverage follows the reconnaissance verdicts fixed in
  Section 4 and recorded in `docs/recon_run2_hs.csv`.
  - 229 rows are `archived`, holding 228 distinct files: the Virginia 2024 and
    2025 rows share one workbook, whose sheet carries both years, so they carry
    the same checksum.
  - **The interactive-tool exports, run 2026-09-15 and 2026-09-16.** The 37 rows
    that were `hand_download` covered nine states — **CT, ID, MI, NE, NV, RI, SD,
    TX and WY for all four end years, and ND 2025** — each publishing through an
    interactive tool (EdSight, the Idaho Report Card downloads modal, MI School
    Data, the NEP download API, Data Interaction, the Assessment Data Portal, a
    MicroStrategy document, the TAPR SAS broker, a WebFOCUS report) rather than
    as a file. The exports were driven and the 37 rows became 69: a state whose
    tool exports one subject at a time now has one row per subject (CT, NE, NV,
    RI, TX and WY: eight rows each), while SD and ND export every subject in
    one file (`hs_<ST>_<sy_end>_all.csv`), and MI has three rows a year, its
    all-subjects file beside the SAT mathematics and SAT reading files (bullet
    below). 65 of the 69 are `archived`, with the export or request steps, the
    layout and the district-by-race row counts in each row's `notes`; the tools
    serve no url, so `url` stays blank and the files are checksummed in place.
    The remaining 4 are ID 2022-2025 (`unavailable`), in the bullet below.
  - **Idaho publishes nothing that meets the matching rule.** The Idaho Report
    Card export does carry district-by-race rows, but `Student Group` is a single
    dimension: the race groups pool every tested grade (ISAT is given in grades
    3-8 and 11) and `High School` is a separate group pooling every race, so
    grade and race are alternatives and never crossed. Run 1 reported Idaho's
    high school ISAT, so Section 4's matching rule cannot be met from
    that source, and the export was not archived. The four rows are `unavailable`
    and each one's `notes` records the export as driven and the legacy SDE
    workbook for that year, with its Wayback url, capture date and checksum.
    **The 2022-2024 legacy workbooks were archived on 2026-09-16** as
    `hs_reportcard_id_sde`, one row per year, from those Wayback replay urls, the
    archived url and capture date in `source`; each checksum matches the one
    recorded on 2026-09-15. Each district sheet crosses `Grade` with `Population`,
    so district rows by Black, Hispanic and White exist for the high school
    result, but **no row is labelled grade 11**: the grade is `High School`, and
    `data/reference/test_replacement.csv` names Idaho's Run 1 test by "high school
    grade" with no number (the grade 11 in the export notes is not in that table).
    The 2022 workbook carries rates only, with no tested count; 2023 and 2024
    carry `ProficiencyDenominator`, blank where the SDE omits a small count.
    **By author decision these rows enter for 2022-2024** (`docs/deviations_run2.md`,
    2026-09-16): the 30-student floor applies to `ProficiencyDenominator` where
    it is printed and Idaho's own minimum group size stands in where it is not.
    The `hs_reportcard_id` rows for 2022-2024 stay `unavailable` for the export. ID
    2025 stays `unavailable` with no alternative: its legacy workbook lists race
    groups and grades as alternatives in one `PopulationName` column, never
    crossed.
  - **Michigan: every requested file has arrived; the SAT rows are cross-tabulated
    only.** MI School Data builds each file on the server and emails it, so there
    is no url. Twelve files were requested on 2026-09-16 — the High School
    Assessments file (`hs_reportcard_mi`, `hs_MI_<sy_end>_all.csv`) and the SAT
    Math and SAT EBRW Proficiency Cross-tabulated Data files
    (`hs_reportcard_mi_math`, `hs_MI_<sy_end>_math.csv`; `hs_reportcard_mi_rla`,
    `hs_MI_<sy_end>_ela.csv`) for each of 2022-2025 — and the author saved all
    twelve by hand from the emails on 2026-09-16. All are archived and
    checksummed.
    - **The High School Assessments files do not carry the rows Section 4
      names.** In every year M-STEP carries Science and Social Studies alone and
      grade-11 ELA and mathematics appear under MI-Access — the alternate
      assessment — only, with no SAT rows. Run 1's Michigan high school result is
      grade 11 SAT Mathematics and SAT Evidence-Based Reading and Writing, which
      EDFacts pools with the alternate; these files are the alternate side alone.
      They are archived as the record of the check, not as outcome data. The
      2024-25 file also carries PSAT 9 and PSAT 10 rows (grades 9 and 10, ELA and
      mathematics, by district and race), which are not the grade 11 SAT; whether
      they bear on Section 9's test-replacement flag is not decided here.
    - **The SAT cross-tabulated files carry grade-11 SAT rows by district and
      race, but not a race-alone row.** Every row is a cell of `Subgroup_1` by
      `Subgroup_2`: race appears only crossed with sex, English learner status or
      disability, neither column has an all-students value, and the files carry
      percent proficient (exact to one decimal, banded, or `*`) with no tested
      count, so rule 3 cannot be applied and a race-alone rate cannot be rebuilt
      from the cells. They are also SAT only, with no alternate to pool. **By
      author decision Michigan 2022-2025 are unavailable** (`docs/deviations_run2.md`,
      2026-09-16): district-by-race rates cannot be formed, so all twelve files
      are archived as the record of the check, not as outcome data. Each row's
      `notes` holds the layout and the row counts.
  - **Iowa carries no district-by-race rows.** The ISASP proficiency workbook
    for each of 2022-2025 was opened: it reports district by grade for all
    students only, with no race or ethnicity subgroup anywhere in the workbook.
    IA is a conditional state under Section 4, so those four state-years do not
    enter; the files stay archived as the record of the check.
  - **Arkansas 2022 carries no district-by-race rows either.** AR 2022 is the
    other Section 4 conditional state-year; its row was added and the file
    downloaded on 2026-09-15. The 2021-22 "Reporting Categories, Avg Scale
    Scores, and Demographics" workbook is the only ACT Aspire file for that
    year that carries race at all, and only at state level: its Demographics
    sheet is 131 rows whose unit reads `Arkansas State` throughout, by grade,
    subject and readiness level, with a column per group. Its Districts sheet
    is district by grade for all students, with no subgroup, and the companion
    post-appeals summary file has no race string anywhere. AR 2022 therefore
    does not enter, and the file stays archived as the record of the check.
    AR 2023-2025 are outside the design's coverage: Section 4 makes only 2022
    conditional, and `docs/recon_run2_hs.csv` records `no subgroup file found`
    for the other three years.
  - Some agencies refuse a scripted request. AZ (Cloudflare, needs a browser
    user agent and the page as referer), CO (302 to resources.finalsite.net,
    name from Content-Disposition), DC (Box download endpoint, needs the cookie
    the share page sets), KY and NM (403 without a browser user agent), MN
    (Radware JavaScript challenge), NH and VA (403 to any scripted client) were
    fetched through a browser and moved into place. `R/02_download.R` verifies
    their checksums but cannot re-fetch them as written; a reader working from
    an empty `data/raw/` needs the browser for those rows.
  - Three states publish percentages without a tested count by group, which Run
    1 rule 3 requires: UT (all four years), VA (both years) and LA (all three).
    Their `notes` carry the caution; whether they can enter is Section 5's
    question, not the manifest's.
  - Not yet in an OSF deposit.
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

Run 2: 
8c0d3f376b14aec2eb55f294346f7874fece0b81c8e85588909c6c49e8088399
3a01bf73a7c0a319e5dc904b0ad920895864cd5d0c2db2a096dc26292cac1cdc
5dad35a9e9e595a670b6e73a9894cc370e27d4b932b27572472b3d99e8ca6bb2


Outputs
run 1 Outputs
c90871524bf5f3e8b8a281f5ab77711b1e31d56d1433ee62121f046832514d79

