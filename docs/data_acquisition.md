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
- EDFacts counts are used only when exact. Percent proficient enters as an
  exact value or at the midpoint of a range no wider than 10 points (author
  decision 2026-09-11, replacing the exact-only rule of Section 5; see 4.1).
  Wider ranges and symbols become missing.
- After each stage the author deposits the downloaded files and the manifest
  on OSF (Section 4). Federal files are public domain.

## 1. What is needed, by stage

| Dataset | Stage 1 (end years) | Stage 2 | Who obtains it |
|---|---|---|---|
| EDFacts achievement, math and RLA, LEA level | 2010-2013 | 2014 to end year | Claude Code, manifest |
| EDFacts participation, math and RLA, LEA level | 2013 (none published earlier) | 2014 to end year | Claude Code, manifest |
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

Preparation: keep exact counts; take percent proficient as the exact value or
the midpoint of a range no wider than 10 points (4.1); convert percent to
share by dividing by 100; apply the 30-test floor per cell; compute V with
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

Participation files begin with SY2012-13. None were published for 2009-10
through 2011-12 (checked on ed.gov and the Education Data Center archive,
2026-09-11); under design v17 those years are retained without the
participation test (Section 5).

Files: `math-participation-lea-syYYYY-YY.csv`, `rla-participation-lea-syYYYY-YY.csv`.
Fields: `S_MTHHSNUMPART_YYYY`, `S_MTHHSPCTPART_YYYY` and the RLA equivalents.

### 2.3 CCD local education agency universe

What: one row per district per year with agency type, operational status,
boundary-change indicator, and totals. Defines the district universe (Section 5).

Where: nces.ed.gov/ccd/files.asp. Choose the school year, level "Public School
District (LEA)", "Nonfiscal", then the universe/directory file. For 2009-10
through 2013-14 the file is the Local Education Agency Universe Survey.
Stage 1 uses the newest release of each year, as flat-text `_txt.zip`
files: `ag092a` (v.2a) for 2009-10, `ag102a` (v.2a) for 2010-11, `ag111a`
(v.1a) for 2011-12, and `ag121a_supp` (v.1a) for 2012-13. The matching
school universe files (2.4) are `sc092a` (v.2a), `sc102a` (v.2a),
`sc111a_supp` (v.1a), and `sc122a` (v.2a). From 2014-15 the CCD switched to
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

Where: same page as 2.3, level "Public School", the School Universe Survey,
then the Membership file from 2014-15 on. Stage 1 uses the newest release of
each year, as flat-text `_txt.zip` files: `sc092a` (v.2a) for 2009-10,
`sc102a` (v.2a) for 2010-11, `sc111a_supp` (v.1a) for 2011-12, and `sc122a`
(v.2a) for 2012-13.

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
fiscal year, then the individual unit data. Stage 1 uses the Census
comma-delimited text files `elsec10.txt` through `elsec13.txt`
(www2.census.gov/programs-surveys/school-finances/tables/YYYY/secondary-education-finance/),
saved as `f33/f33-fyYYYY.csv`. These carry `V33`; the `elsecYYt` table
files report `ENROLL` instead and are not used. NCES
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

`data/reference/test_replacement.csv`, one row per state and school year:
the 50 states plus DC (no PR, BIE, or VI). Stage 1 covers end years
2010-2013 (204 rows); stage 2 extends it to the end year. Columns: `state`,
`sy_end`; `replaced_math`, `replaced_rla` (0/1 per subject); `replaced` (1
if either subject is 1); `assessment_math`, `assessment_rla` (the regular
high school test behind that year's EDFacts high school result); `source`
(every source for the row, separated by ` | `); `evidence` (`documented` or
`inferred`); `notes`.

Rules (author, 2026-09-11):
- A subject is 1 in the first school year in which the EDFacts high school
  result for that subject comes from the new test. A test rebuilt for new
  standards with a new scale is a replacement even if the name is unchanged;
  a new cut score on an unchanged test is 0.
- A year that mixes old and new results is flagged: `notes` begins `MIXED:`.
- Sources, in order: the state education agency's assessment history page
  (Wayback Machine copies allowed, cited with the archived URL and capture
  date); the state's ESEA flexibility request (author, 2026-09-11: an
  approved source, labelled separately from SEA pages), ESEA accountability
  workbook, or ESSA plan. The EDFacts
  "significantly changed" lists (FAQ of the SY2011-12 and SY2012-13
  documentation) are pointers only. The Appendix D mappings in the EDFacts
  documentation name no tests (they map performance levels to proficiency by
  assessment type) and cannot code a row.
- Documented rows get evidence `documented`; a state-year with no documented
  change is coded 0 with evidence `inferred`.
- Wyoming 2009-10: the online administration failed and no valid results
  exist; the row is coded from the test administered, with a note.

Drafting conventions (Claude Code, 2026-09-11; author to confirm):
- The 1 goes on the first year any part of the high school result comes from
  the new test; that year and any later mixed year carry `MIXED:`.
- Only the regular assessment is coded; alternate-assessment changes go in
  `notes`.
- A change of tested grade with the same test program and scale is 0, with
  `notes` beginning `CHECK:`. `CHECK:` also marks a documented change whose
  year is ambiguous.
- `documented`: a cited source states which test was used that year or
  documents the change in that year. `inferred`: coded 0 because no change
  was documented. A 1 is never inferred.
- Where a state has no single history page, SEA-published program overviews,
  technical reports, and press releases count as the SEA source.
- Source format: `SEA: <url> (accessed YYYY-MM-DD)`,
  `Wayback: <archived url> (captured YYYY-MM-DD)`,
  `ESEA flexibility request: <url>`, `ESEA workbook: <url>`,
  `ESSA plan: <url>`.
- A change in which instrument is reported counts as a replacement (author,
  2026-09-11): Maine 2011 math (augmented SAT to SAT alone), Utah 2011 math
  (Algebra I and Geometry CRTs to Algebra I alone), and Mississippi 2013
  reading (English II loses its writing part; mixed year) are 1. North
  Carolina 2012 reading is 1 only if North Carolina's documentation shows the
  pre-2012 EDFacts reading result included the Grade 10 Writing component.
- Row decisions from the author (2026-09-11) are recorded in `notes` as
  "Author decision 2026-09-11: ...".
- Stage 1 re-run (2026-09-11): the MT, NE, NV, NH, NJ, NM, NY, NC rows,
  first drafted without web search, were re-run with web search. Their
  `evidence` follows the documented/inferred rules above, and rows with no
  source for the year list the searches tried in `notes`.

The author checks every row before it is used.

### 3.3 CEP phase-in table

`data/reference/cep_phase_in.csv`, columns `state, first_cep_sy_end, source`:
the first school year (end year) districts in the state could participate in
the Community Eligibility Provision, from a USDA Food and Nutrition Service or
Food Research & Action Center source. Used for the stage-1 years, when the
CCD has no CEP field (see 2.5).

## 4. What "prepared" means

`R/03_sample.R` produces one district-year file with: LEAID, state, sy_end,
retained flag and reason, agency type, boundary flag, SAIPE 2009 quintile,
CEP indicator, test-replacement flag, participation by subject, and, by
subject and subgroup, the valid-test count, the percent proficient that
enters the gap, and the width of its reported range.

`R/04_outcomes.R` produces one row per district-year-subject with V for the
Black-White and Hispanic-White gaps with counts and delta-method standard
errors, and one row per state-year-subject with the top-versus-bottom poverty
quintile gap from enrollment-weighted district means.

Both scripts print the counts the design asks for: districts retained by
rule, cells lost to suppression, state-years lost to participation, and
cohorts per event time.

### 4.1 Sample rules as implemented (author decisions, 2026-09-11)

`R/03_sample.R` writes `data/derived/sample_district_year.csv`; the shared
rules are in `R/functions/sample_rules.R`.

- Stability (Section 5, rule 2). The CCD LEA universe files for 2009-10
  through 2012-13 have no separate status field; `BOUND` carries it: 1 no
  change, 2 closed, 3 new, 4 added, 5 significant change in boundaries or
  instructional responsibility, 6 temporarily closed, 7 future, 8 reopened.
  A district is present in a year when it is listed with a code other than 2,
  6, or 7, and it must be present in every window year. A code 5 or 8 in any
  window year, 2009-10 included, excludes it (8, reopened, is treated like
  the other change codes: author decision 2026-09-11). Agency type must be
  1 or 2 in every window year.
- Suppression (rule 3; author decision 2026-09-11, replacing the exact-only
  rule; logged in `docs/decision_log.md`). The valid-test count must be exact
  and at least 30. Percent proficient enters as the exact value or, when
  EDFacts reports it as a range no wider than 10 percentage points, at the
  range midpoint. Wider ranges and suppressed values (`PS`, `N/A`, `.`,
  blank) are missing. Width and midpoint come from the printed endpoints,
  with one-sided labels closed at 0 and 100 (`edfacts_range()`): `20-29` has
  width 9 and midpoint 24.5, `90-94` width 4 and midpoint 92, `GE90` width 10
  and midpoint 95, `GE95` width 5 and midpoint 97.5, `LE5` width 5 and
  midpoint 2.5, an exact value width 0. The stage-1 files band high school
  percent proficient by tested count: 1-5 `PS`; 6-15 `GE50`/`LT50`; 16-30
  20-point bands; 31-60 10-point bands; 61-300 5-point bands; above 300 whole
  numbers with `GE99` and `LE1` at the ends
  (`outputs/03_sample/range_widths_by_bracket.csv`). In those files the
  primary rule admits every cell with 31 or more tested students. Statuses:
  `not_reported`, `below_30`, `suppressed`, `wide_range`, `usable`.
- Suppression robustness samples (author decision 2026-09-11): exact values
  only (width 0, the registered rule) and ranges of 5 points or less.
  `MAX_WIDTH` and `cell_in_sample()` in `R/functions/sample_rules.R` define
  the three samples. The sample file carries `w_<subj>_<sg>` (width in
  points; 0 exact; NA suppressed) and `p_<subj>_<sg>` (the exact value or
  midpoint, usable cells only) for `R/04_outcomes.R`.
- SAIPE (author decision 2026-09-11; logged in `docs/decision_log.md`). A
  district that passes rules 1 and 2 but has no SAIPE 2009 child-poverty rate
  (absent from the file, or no children 5-17) is dropped before rule 6, for
  all three gaps. The dropped LEAIDs are listed in
  `outputs/03_sample/no_saipe_2009.csv`.
- Participation (rule 4; author decision 2026-09-11, replacing the
  lower-bound reading; logged in `docs/decision_log.md`). EDFacts reports most
  high school participation rates as bands (`GE95`, `GE90`, `90-94`). The 95
  percent test applies to the exact value where one is reported and to the
  band midpoint where participation is banded (`part_value()`, printed
  endpoints as in rule 3): `GE90` (95), `GE95` (97.5) and `GE99` (99.5) pass;
  `90-94` (92), `80-89`, `GE80`, `GE50` and lower bands fail. `PS`, `n/a`, `.`
  and blank fail because no participation is reported. The exact-only sample
  keeps exact participation values. Its cells report participation as an
  exact value or `GE99`, which passes, so one `part_ok_*` flag serves all
  three samples; `R/03_sample.R` stops if a wider band appears there. End
  years 2010-2012 are retained without the test; `robust_from_2013` marks the
  robustness sample.
- Poverty quintiles (Section 6, gap (a)). Fixed per state. The quintile set is
  the districts that pass rules 1 and 2, have a SAIPE 2009 rate (children
  5-17 in poverty over children 5-17), and have a 2009-10 CCD grade span
  reaching grade 12. They are ranked by the rate, ties broken by LEAID, and
  split into five groups of equal count (1 = lowest poverty). The same
  assignment holds in every year.
- CEP (stage 1). `cep` = 1 when the end year is on or after the state's
  `first_cep_sy_end` in `data/reference/cep_phase_in.csv`: state
  availability, not district adoption.
- Treatment timing (rule 6). `retained`, `retained_r1` and `retained_r2`
  apply rules 1, 2 and 6 with `event_table.csv`, `event_table_r1.csv` and
  `event_table_r2.csv`. Only each state's group is read; treatment years stay
  out of the sample file.

### 4.2 Outcomes as implemented (author decisions, 2026-09-11)

`R/04_outcomes.R` writes `data/derived/gaps_race_district_year.csv` (gaps (b)
and (c)) and `data/derived/gap_poverty_state_year.csv` (gap (a)); the shared
functions are in `R/functions/outcomes.R`. Decisions are logged in
`docs/decision_log.md`.

- Inputs. Valid-test counts, `p_<subj>_<sg>` and `w_<subj>_<sg>` come from
  `data/derived/sample_district_year.csv`. Percentages are divided by 100 and
  passed to `v_gap()` and `v_gap_se()`. Gap (a) district scores use
  `probit_score()`, which applies the same clamp as `v_gap()`.
- Samples. All three suppression samples (`primary`, `r5`, `exact`), named in
  a `sample` column. They are nested, and a gap has the same value in every
  sample that holds it.
- Cells. A gap uses a district-year-subject only when every subgroup in it
  passes rule 3 in that sample and, from 2012-13, rule 4.
- Sign. Black minus White and Hispanic minus White; gap (a) is the
  highest-poverty quintile minus the lowest. Reardon's convention is the
  reverse.
- Gap (a). The mean district probit score in quintile 5 minus quintile 1,
  weighted by 2009-10 CCD total membership (`MEMBER`), fixed across years,
  over districts with a usable all-students cell that year. A district
  without a valid 2009-10 membership is left out of gap (a) and stays in
  (b) and (c); in stage 1 that is four California quintile-5 districts.
  A state-year without a usable district in quintile 1 or 5 gets no row, so
  DC and HI (one quintile district each) never do.
- Rows. Both files cover districts retained under at least one event set and
  carry `retained`, `retained_r1` and `retained_r2`. In gap (a) these are
  state-level.
- Standard errors. Delta method, binomial sampling in each share only. They
  do not include the error from entering a range at its midpoint.
- Math and RLA are separate rows; averaging within district-year is left to
  the estimation steps. Cohorts per event time are reported by
  `R/05_primary.R`, since step 4 reads no treatment years.

## 5. Stage 2 additions

- Add manifest rows for every dataset for end years 2014 through the end year
  fixed at registration. EDFacts from 2022 onward comes from the ED Data
  Library in a different layout; the loader must be extended without changing
  any rule.
- Extend `test_replacement.csv` and the CEP indicator through the end year.
- The author rechecks the pending court cases listed in the private candidates file.

### 5.1 Stage 2 as downloaded (2026-09-12)

`data/stage.txt` is `2`. 117 rows were added to the manifest and
`R/02_download.R` archived every one that has a url. Where a row points and
what is missing:

- **EDFacts achievement and participation, LEA, end years 2014-2021.** The
  legacy `www.ed.gov/sites/ed/files/about/inits/ed/edfacts/data-files/` names
  serve 2014-2018 and 2021. They 404 for SY2018-19, so end year 2019 comes from
  the ED Data Library: `SY1819_FS175_DG583` (math performance),
  `SY1819_FS178_DG584` (RLA performance), `SY1819_FS185_DG588` (math
  participation) and `SY1819_FS188_DG589` (RLA participation), each a zipped
  CSV under `eddataexpress.ed.gov/sites/default/files/data_download/EID_*/`.
  Those four files are in the ED Data Library's long layout — one row per
  LEA-subgroup-measure with columns `School Year, State, NCES LEA ID, LEA,
  School, NCES SCH ID, Data Group, Data Description, Value, Numerator,
  Denominator, Population, Subgroup, Characteristics, Age/Grade, Academic
  Subject, Outcome, Program Type` — so the loader has to read both layouts.
  The high school band is `Age/Grade`, the percent proficient (exact value or
  range) is `Value`, and the valid-test count is `Denominator`; the range and
  suppression rules of 4.1 apply unchanged. End year 2020 has no assessment
  file at any level and is excluded by design Section 3, so it has no row.
- **EDFacts adjusted cohort graduation rate, LEA, end years 2011-2024**
  (`edfacts_acgr_lea`, secondary outcome, design Section 6). Legacy per-year
  CSVs `acgr-lea-syYYYY-YY.csv` for 2011-2018; ED Data Library zips
  `SY1819_`, `SY1920_` and `SY2021_FS150_FS151_DG695_DG696_LEA` for 2019, 2020
  and 2021. **Nothing exists for end years 2022, 2023 and 2024.** Checked
  2026-09-12: the ED Data Library's file-spec 150 listing holds LEA files only
  through 2020-21, SEA files for 2021-22 and 2022-23, and nothing at all for
  2023-24; the legacy names 404 for all three years. Those three rows, and the
  three matching documentation rows, carry no url and stay that way. The
  graduation window is therefore end years 2011 through 2021, not the 2023-24
  of design Section 3, and end year 2020 is kept for this outcome alone
  (author, 2026-09-12; `docs/deviations.md`, Section 3).
- **Documentation.** `edfacts_docs` now carries the assessment documentation
  for end years 2014-2019 and 2021 and `edfacts_acgr_docs` the graduation
  documentation for 2011-2021, all in `data/raw/edfacts/docs/`. ED published no
  assessment documentation for SY2019-20 and no graduation documentation for
  2021-22 onward; those rows carry no url.
- **CCD, end years 2014-2024.** End year 2014 is the last combined universe
  file (`ag131a_supp_txt.zip`, `sc132a_txt.zip`). From 2014-15 each year has
  three rows: `ccd_lea_directory` = the LEA Directory file `ccd_lea_029_*`,
  `ccd_membership` = the school Membership file `ccd_sch_052_*`, and
  `ccd_lunch_program` = the school Lunch Program Eligibility file
  `ccd_sch_033_*`, which carries the CEP field from 2014-15 (2.5). Urls are the
  newest release of each year in the NCES file API
  (`nces.ed.gov/ccd/datatables/api/File/2/{5|7}/{yearId}/0/0/0`), flat text
  where a release offers a format choice. The split means the LEA Directory
  file no longer carries `MEMBER` or `BOUND`; the stability and type rules of
  4.1 have to be re-expressed in its own fields when `R/03_sample.R` is
  extended.
- **SAIPE, income years 2013-2023**, pairing with school years ending
  2014-2024 (2.6).
- **F-33, FY2014-FY2024** (2.7). FY2022 is the one row that is not
  `elsecYY.txt`: `elsec22.txt` holds 1,730 of the 14,106 unit records Census
  published that year (17 Alabama systems against 138 in the companion flag
  file `elsec22f.txt`), so the row archives `elsec22.xlsx`, which holds all
  14,106. The loader reads that one year from the spreadsheet.
