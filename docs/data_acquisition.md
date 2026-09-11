# Data acquisition and preparation

Companion to `docs/design.md`; section numbers below refer to that document.
Read this before touching the manifest or writing `R/03_sample.R` and
`R/04_outcomes.R`.

## 0. Rules that apply to every file

- Every file is listed in `data/manifest/download_manifest.csv` and downloaded
  by `R/02_download.R`, which records a SHA-256 and a timestamp (Section 4).
  No file is fetched by hand except where a site blocks scripts (noted below);
  a hand-downloaded file still gets a manifest row, and the script computes its
  checksum on the next run.
- Two stages (Sections 4, 10, 11). Stage 1: school years ending 2010 through
  2013, for the power simulation. Stage 2: every later year through the newest
  EDFacts release on the registration date. `data/stage.txt` gates this.
- School years are indexed by end year: 2009-10 is 2010. Fiscal years in F-33
  and SAIPE income years are mapped to school years as stated per dataset.
- Only exact values are used from EDFacts (Section 5). Ranges and symbols
  become missing through `edfacts_exact()`.
- After each stage the author deposits the downloaded files and the manifest
  on OSF (Section 4). Federal files are public domain.

## 1. What is needed, by stage

| Dataset | Stage 1 (end years) | Stage 2 | Who obtains it |
|---|---|---|---|
| EDFacts achievement, math and RLA, LEA level | 2010-2013 | 2014 to end year | Claude Code, manifest |
| EDFacts participation, math and RLA, LEA level | 2010-2013 | 2014 to end year | Claude Code, manifest |
| CCD LEA universe / directory | 2010-2013 | 2014 to end year | Claude Code, manifest |
| CCD school universe / membership by grade and race | 2010-2013 | 2014 to end year | Claude Code, manifest |
| CCD school lunch program (CEP participation) | phase-in table only | 2015 to end year | Claude Code |
| SAIPE school district poverty | 2009-2012 | 2013 to end year minus 1 | Claude Code, manifest |
| F-33 school finance | FY2010-FY2013 | FY2014 to end year | Claude Code, manifest |
| BLS CPI-U monthly | all months 2009 onward | refresh | Claude Code or hand download |
| LRS (2018) reform list | done (verify) | — | you |
| Statute-rule events after 2011 | done (verify) | recheck at registration | you |
| Court rulings after 2011 | done (verify) | recheck at registration | you |
| Test-replacement table | 2010-2013 | extend to end year | Claude Code drafts, you verify |

## 2. Federal files

### 2.1 EDFacts state assessment results (achievement)

What: percent of students at or above the state proficiency cut, by LEA, by
subject, by grade span, by subgroup, with the number of valid tests. This is
the outcome source (Section 6).

Where: the EDFacts public data files for SY2008-09 through SY2020-21 were
published by the Department of Education under "EDFacts data files" (the
documentation lives under ed.gov/about/inits/ed/edfacts/data-files/). Beginning
with SY 2021-22, ED moved state assessment results to ED Data Express, with
downloads in the ED Data Library. If an ED page has moved, two public archives
hold the same files: the Education Data Center (zelma.ai/edfacts) and the
DataLumos archive of the ED Data Library ZIP files. Prefer ed.gov. Record
whichever source was used in the manifest `url` column.

Files per year: `math-achievement-lea-syYYYY-YY.csv` and
`rla-achievement-lea-syYYYY-YY.csv`. School-level files exist but are not needed.

Fields that matter (names vary slightly by year; Claude Code maps them):
- `LEAID` (7-digit; keep as text), `STNAM`, `FIPST`
- for subgroup S in {ALL, MWH, MBL, MHI, ECD}: `S_MTHHSNUMVALID_YYYY`
  (valid tests, high school) and `S_MTHHSPCTPROF_YYYY` (percent proficient);
  same pattern with `RLA`.
- Grade span `HS` is the high school band. Do not use `00` (all grades).

Preparation: keep exact numeric values only; convert percent to share by
dividing by 100; apply the 30-test floor per cell; compute V with
`v_gap(p_a, p_b, n_a, n_b)`.

Known quirks: some states report only `00`; some report high school under
grade `HS` in one year and a numbered grade in another; subgroup codes changed
in 2010-11 with the new race categories. The documentation Word file for each
release lists these anomalies and the state-specific proficiency level
mappings. Download that documentation alongside the data and keep it in
`data/raw/edfacts/docs/`.

### 2.2 EDFacts participation

What: percent of enrolled students tested, same structure as 2.1. Used for the
95 percent participation rule (Section 5).

Files: `math-participation-lea-syYYYY-YY.csv`, `rla-participation-lea-syYYYY-YY.csv`.
Fields: `S_MTHHSNUMPART_YYYY`, `S_MTHHSPCTPART_YYYY` and the RLA equivalents.

### 2.3 CCD local education agency universe

What: one row per district per year with agency type, operational status,
boundary-change indicator, and totals. Defines the district universe (Section 5).

Where: nces.ed.gov/ccd/files.asp. Choose the school year, level "Public School
District (LEA)", "Nonfiscal", then the universe/directory file. For 2009-10
through 2013-14 the file is the Local Education Agency Universe Survey
(`ag091a`, `ag101a`, `ag111a`, `ag121a`). From 2014-15 the CCD switched to
separate Directory, Membership, and Characteristics files.

Fields: `LEAID`, `TYPE` (agency type), `STATUS`, `BOUND` (boundary change
indicator), `MEMBER`, `CHARTR` where present.

Preparation: keep agency type 1 and 2 (regular local school districts). Drop
supervisory union centers, regional service agencies, state and federal
agencies, and charter-only agencies. Apply the status and boundary rules in
Section 5 to decide which district-years are retained.

### 2.4 CCD school universe (membership)

What: school-level membership by grade and by race/ethnicity. Aggregated to
the district for the pre-treatment racial composition covariate (Section 7)
and for the grade-9-to-12 enrollment ratios in the dropout check (Section 9).

Where: same page as 2.3, level "Public School", the School Universe Survey
(`sc091a` through `sc121a`), then the Membership file from 2014-15 on.

Fields: `NCESSCH`, `LEAID`, grade counts `G09`-`G12`, race counts
(`WHITE`, `BLACK`, `HISP`, and the post-2010 categories).

### 2.5 CCD school lunch program (CEP)

What: whether a school participates in the Community Eligibility Provision.
CEP adoption is a time-varying control (Section 7) and explains breaks in
free-lunch counts (Section 9).

Where: from SY2014-15 the CCD school Characteristics or Lunch Program file
carries a lunch program field with a CEP value. For the stage-1 years the CCD
has no CEP field. Use the USDA phase-in schedule instead, coded at the state
level: pilots began in 2011-12 in Illinois, Kentucky, and Michigan; 2012-13
added the District of Columbia, New York, Ohio, and West Virginia; 2013-14
added Florida, Georgia, Maryland, and Massachusetts; 2014-15 nationwide.
Verify that schedule against a USDA or FRAC source and record the source in
`data/reference/cep_phase_in.csv`.

Preparation: district-year indicator = any school in the district under CEP.

### 2.6 SAIPE school district estimates

What: children aged 5-17 in poverty, by district, annual. Source of the
poverty quintiles fixed at 2009 (Section 5) and the pre-treatment poverty
covariate (Section 7).

Where: census.gov/programs-surveys/saipe/data/datasets.html, then the year,
then "School District Estimates" (`ussdYY.txt` or the Excel version).

Fields: state FIPS, district ID (5 digits), name, total population,
population 5-17, population 5-17 in poverty. LEAID = state FIPS + district ID.

Mapping: SAIPE income year Y pairs with school year ending Y+1 (SAIPE 2009
with 2009-10). The quintiles use SAIPE 2009 only.

### 2.7 F-33 Annual Survey of School System Finances

What: district revenue by source and enrollment. Source of per-pupil
state-plus-local revenue for dose scaling (Section 7).

Where: census.gov/programs-surveys/school-finances/data/tables.html, the
fiscal year, then the individual unit data or table (`elsecYYt`). NCES
republishes the same survey as the CCD School District Finance Survey with SAS
and text formats; either is acceptable, record which.

Fields: `NCESID` (LEAID), `TSTREV`, `TLOCREV`, `TFEDREV`, `TOTALREV`,
`V33` (fall enrollment).

Mapping: fiscal year 2010 is school year 2009-10, so FY = end year.

Preparation: per-pupil state-plus-local revenue = (TSTREV + TLOCREV) / V33,
deflated with `deflate_to_base()` to dollars of the last window year.

### 2.8 BLS CPI-U

What: monthly CPI-U, U.S. city average, all items, not seasonally adjusted,
series `CUUR0000SA0` (Section 7).

Where: data.bls.gov/timeseries/CUUR0000SA0 (choose all years, download as
CSV) or the flat file `cu.data.1.AllItems` under
download.bls.gov/pub/time.series/cu/. BLS refuses requests that look
scripted. If `R/02_download.R` fails on this row, download in a browser, save
as `data/raw/cpi/cuur0000sa0.csv`, and rerun the script so it records the
checksum.

Preparation: `cpi_school_year()` averages July through June. Every school year
in the window must be flagged complete.

## 3. Author-supplied inputs and reference tables

### 3.1 Event files (private folder; never read them in a session)

`lrs_events.csv`, `court_events_after_2011.csv`,
`legislative_events_after_2011.csv`: columns `state, event_year, event_type,
source, notes`; `event_year` is the end year of the school year (a ruling or
enactment in calendar year Y is coded Y+1); `event_type` is court,
legislative, or referendum; `source` is LRS, ELC-SC, ELC-LC, or STAT.
`R/01_build_event_table.R` (author-run) turns them into the permuted tables
`data/reference/event_table.csv` (full set, primary), `event_table_r1.csv`
(LRS plus final supreme court rulings), and `event_table_r2.csv` (court
events only). `post2011_candidates_considered.csv` is the coding table
deposited with the registration. `permutation_seed.txt` holds the blinding
seed and is never used by repository code.

### 3.2 Test-replacement table

`data/reference/test_replacement.csv`, columns `state, sy_end, replaced`
(0/1), `assessment_name, source`. `replaced` = 1 in the first school year a
different high school assessment was administered; a new cut score on the
same test is 0. Sources, in order: the state-specific assessment mappings in
the appendix of each EDFacts assessment documentation file
(`data/raw/edfacts/docs/`); the state education agency's assessment history
page; the state's ESEA accountability workbook or ESSA plan. Stage 1 covers
2010-2013; stage 2 extends it to the end year. The author checks every row
before it is used.

### 3.3 CEP phase-in table

`data/reference/cep_phase_in.csv`, columns `state, first_cep_sy_end, source`:
the first school year (end year) districts in the state could participate in
the Community Eligibility Provision, from a USDA Food and Nutrition Service or
Food Research & Action Center source. Used for the stage-1 years, when the
CCD has no CEP field (see 2.5).

## 4. What "prepared" means

`R/03_sample.R` produces one district-year file with: LEAID, state, sy_end,
retained flag and reason, agency type, boundary flag, SAIPE 2009 quintile,
CEP indicator, test-replacement flag, participation by subject, and valid-test
counts by subgroup.

`R/04_outcomes.R` produces one row per district-year-subject with V for the
Black-White and Hispanic-White gaps with counts and delta-method standard
errors, and one row per state-year-subject with the top-versus-bottom poverty
quintile gap from enrollment-weighted district means.

Both scripts print the counts the design asks for: districts retained by
rule, cells lost to suppression, state-years lost to participation, and
cohorts per event time.

## 5. Stage 2 additions

- Add manifest rows for every dataset for end years 2014 through the end year
  fixed at registration. EDFacts from 2022 onward comes from the ED Data
  Library in a different layout; the loader must be extended without changing
  any rule.
- Extend `test_replacement.csv` and the CEP indicator through the end year.
- The author rechecks the pending court cases listed in the private candidates file.
