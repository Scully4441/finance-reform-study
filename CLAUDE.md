# Finance reform study — project instructions

Dissertation pipeline: the effect of state school finance reforms on secondary
achievement gaps. The design is fixed in `docs/design.md`.
Code implements that document. It does not reinterpret it. If a step needs a
decision the document does not make, stop and ask the author before coding it.

## Hard rules

1. Never list, open, read, or ask about `../finance-reform-study-private/`.
   It holds the real reform tables and the permutation seed.
2. The event tables `data/reference/event_table*.csv` are PERMUTED until
   `data/reference/blinding_status.txt` reads `REAL`. Never edit those files.
   Only `R/09_unblind.R`, run by the author after the `freeze` git tag, changes them.
3. Download stage gate. `data/stage.txt` is `1` until the OSF registration is
   filed. While it is `1`, no EDFacts outcome file for a school year ending
   after 2013 is downloaded, opened, or inspected. `R/02_download.R` enforces
   this. Do not work around it. The author changes the file to `2` after registration.
4. Master seed is 130 (`R/functions/seeds.R`). Every random step calls
   `seed_for("<step name>")`. Never call `set.seed()` with a literal anywhere else.
5. Before registration, author decisions go in `docs/decision_log.md` with a
   rationale; after registration, departures go in `docs/deviations.md`.
   Never edit `docs/design.md`.
6. All estimation in R. Reference packages: `did` (Callaway–Sant'Anna),
   `fixest` (Sun–Abraham `sunab`, stacked regression), `didimputation`,
   `synthdid`, `fwildclusterboot` (Webb weights), `wildrwolf`, `HonestDiD`.
   Versions are recorded in `outputs/package_versions.csv`.
7. Do not print or summarize treatment years from the event table in chat
   output while the status is PERMUTED. Counts by group are fine.

## Conventions

- School years are indexed by their end year: 2010–11 is `2011`.
- States: two-letter postal code. Districts: 7-digit NCES LEAID as character.
- Windows laptop, 14 cores: `future::plan(multisession, workers = 12)`. No forking.
- Scripts are numbered in run order. Shared logic goes in `R/functions/`.
- Every script writes to `outputs/<step>/` and a log to `outputs/logs/`.
- Tests live in `tests/`. Run `Rscript tests/run_tests.R` before every commit.
- Before the freeze: `renv::init()` then `renv::snapshot()`; switch the
  Dockerfile to `renv::restore()`.
- The study is complete. No further analytic change is made without a new
  entry in `docs/deviations.md` (Run 1) or `docs/deviations_run2.md` (Run 2).

## Run order

| Step | Script | Who runs it | Status |
|---|---|---|---|
| 0 | `R/00_install_packages.R` | Claude Code | **complete, commit f585a04** |
| 0r | Environment lock — `renv.lock`, `Dockerfile` (`renv::restore()`, R 4.6.1) | Claude Code | **complete, commit ef9a54b**; complete (2026-09-13); image holds code and the lockfile only, the repository is mounted as `/study` at run time; `tests/run_tests.R` passes in the container |
| 1 | `R/01_build_event_table.R` | author, plain terminal | **complete, commit 1fcbdff** |
| 2 | `R/02_download.R` (all manifest rows) | Claude Code | **complete, commit 2036510**; stage 1 complete (2026-09-11); stage 2 complete (2026-09-12); the graduation-rate rows for end years 2022-2024 stay blank, no LEA file is published; `ccd_school_characteristics` rows for end years 2015-2021 added and archived (2026-09-12), the CEP field being in that file and not the lunch program file; `ccd_membership` rows for end years 2007-2009 added and archived (2026-09-14), for the Lee shares, not yet in an OSF deposit |
| 3 | `R/03_sample.R` — sample rules, design Section 5 | Claude Code | **complete, commit e0960f7**; complete (2026-09-11); range midpoints (2026-09-11); full window 2010-2019 and 2021 (2026-09-12), end year 2019 from the EDC archive (ED's release truncated), LEA_TYPE/UPDATED_STATUS for TYPE/BOUND |
| 4 | `R/04_outcomes.R` — gaps (a) (b) (c), design Section 6 | Claude Code | **complete, commit e0960f7**; complete (2026-09-11); full window (2026-09-12) |
| 3g | `R/03g_graduation_sample.R` — graduation sample, design v18 Sections 5, 6 | Claude Code | **complete, commit 964d840**; complete (2026-09-12) |
| 4g | `R/04g_graduation_outcomes.R` — graduation gaps, design v18 Section 6 | Claude Code | **complete, commit 964d840**; complete (2026-09-12) |
| 5 | `R/05_primary.R` — Callaway–Sant'Anna, design Section 7 | Claude Code | **complete, commit e0960f7**; complete (2026-09-11); unbalanced panel primary, balanced panel robustness (2026-09-11); graduation pass `--outcome graduation`, 24 models (2026-09-12); both outcomes rerun on the full window (2026-09-12) |
| 6 | `R/06_secondary.R` — four secondary estimators | Claude Code | **complete, commit dc44828**; complete (2026-09-11), primary event set, step 5 balanced panels; graduation pass, all three event sets (2026-09-12); full window (2026-09-12), CEP district-year for (b)/(c) and a share for (a); moved to the unbalanced panel, balanced versions in `outputs/06_secondary/appendix/` (2026-09-13); achievement pass on all three event sets (2026-09-13, step 10) |
| 7 | `R/07_inference.R` — bootstrap, RI, Romano–Wolf, HonestDiD, Section 8 | Claude Code | **complete, commit 8087bdd**; complete (2026-09-11), 30 models; graduation pass, 24 models (2026-09-12); full window at the registered counts (9,999 / 10,000), both outcomes (2026-09-13), with ties counted in the randomization p-value; HonestDiD bound sets recomputed on widened grids, `--honest-only` (2026-09-14) |
| 8 | `R/08_power.R` — placebo simulation on 2010–2013, Section 10 | Claude Code | **complete, commit 16ef120**; complete (2026-09-11); six-state registered run for end year 2021, observed-cohort, ten-state and twelve-state sensitivity runs |
| — | Author files the OSF registration; sets `data/stage.txt` to `2` | author | **complete, commit d48530e**; complete (2026-09-11) |
| 9 | `R/09_unblind.R` after `git tag -a freeze` | author, plain terminal | **complete, commit ff96e78 (tag `freeze` at f553bb0)** |
| 10 | `R/10_run_all.R` — full run and reporting, Section 13 | Claude Code | **complete, commit 6aa17dd (tag `run1-final`)**; complete (2026-09-14), full rehearsal on the PERMUTED tables: steps 3–7 at the registered counts, 123 robustness-variant models, Lee bounds, dose scaling, `outputs/13_report/`; rerun after unblinding; `--resume` continues an interrupted run, `--report` rebuilds the report; pre-freeze corrections (HonestDiD grid, revenue floor, CCD 2007–2009) rerun for variants, Lee, dose and report (2026-09-14); **full run on the REAL tables complete** (run 20260914T210951Z, 7.83 h over parts; 2026-09-15), with two post-freeze corrections in docs/deviations.md: the report shows a missing model's status in place of numbers, and HonestDiD bound sets on a reduced consecutive event-time block (`--honest-block`) for models whose event times are not consecutive |
| 2 (run 2) | `R/02_download.R` (run 2 rows) — extension design (`docs/design_extension.md`) Section 4 | Claude Code | **complete, commit 35778cd**; Run 2 registration filed, `data/stage_run2.txt` = `2`, logs opened (`docs/decision_log_run2.md`, closed at registration; `docs/deviations_run2.md`, empty). SEDA 2025.2 complete (2026-09-15): `seda_admindist_long_cs`, `seda_codebook_admindist` and `seda_documentation` rows from the Stanford Digital Repository (DOI 10.25740/np279jm6134), downloaded to `data/raw/seda/` and checksummed; no `sy_end`, one file per release; under the data use agreement (accepted 2026-09-01) that folder is never deposited, see the never-deposited section of `data/manifest/README.md`. State high school report cards complete (2026-09-15): 198 `hs_reportcard_*` rows for end years 2022-2025 over 41 states and DC appended to the manifest, 161 archived under `data/raw/hs_reportcards/` and checksummed, 37 left for hand download (CT, ID, MI, NE, NV, RI, SD, TX, WY all four years, plus ND 2025), all recorded in the new `status` column (`archived` / `hand_download` / `not_published`) that the manifest gained with the `state`, `page_url`, `source` and `notes` columns. Interactive-tool exports complete (2026-09-16): the 37 hand-download rows became 61 (one row per subject where the tool exports a subject at a time), 54 archived and checksummed, leaving `hs_reportcard_id` 2022-2025 `unavailable` (the Idaho export never crosses grade with race, so Section 4's grade-11 matching rule cannot be met). Idaho legacy SDE workbooks complete (2026-09-16): end years 2022-2024 downloaded from the Wayback replay urls in the ID notes to `data/raw/hs_reportcards/ID/` as `hs_reportcard_id_sde` rows (archived url and capture date in `source`), checksums matching those recorded 2026-09-15; each crosses district, grade and race, but its grade is `High School`, no row is labelled grade 11 (`test_replacement.csv` says "high school grade" with no number), and 2022 carries no tested count; by author decision they enter (docs/deviations_run2.md, 2026-09-16: the 30 floor on `ProficiencyDenominator` where printed, Idaho's minimum group size where not). ID 2025 stays `unavailable` (its legacy workbook lists race and grade as alternatives, never crossed). Michigan complete (2026-09-16): the twelve MI School Data files (High School Assessments, SAT Math and SAT EBRW Proficiency Cross-tabulated Data, 2022-2025), saved by hand from the emails, are archived and checksummed as `hs_reportcard_mi` (`_all`), `hs_reportcard_mi_math` and `hs_reportcard_mi_rla`, the request steps in the notes. The four High School Assessments files carry no SAT rows — grade-11 ELA and mathematics are MI-Access alone (2025 adds grade 9-10 PSAT) — and are archived as the record of the check, not as outcome data. The eight SAT cross-tabulated files carry grade-11 SAT district rows by race only crossed with sex, English learner status or disability — no race-alone or all-students row, no tested count, SAT only — so by author decision Michigan 2022-2025 are unavailable and all twelve files are the record of the check. Coverage exclusions recorded (2026-09-16, docs/deviations_run2.md, Section 4): IA 2022-2025, AR 2022, ID 2025 and MI 2022-2025 do not enter; ID 2022-2024 enter from the SDE workbooks; the browser-fetched AZ, CO, DC, KY, MN, NH, NM and VA files; the blank-url checksum change to `R/02_download.R`. `status` gained `requested` (now 0 rows) and `unavailable`; `R/02_download.R` now checksums a row whose file is in `data/raw/` even when the row has no `url`, which is how the hand-exported files are verified. The manifest holds 401 rows, 233 of them `hs_reportcard_*`; the two Section 4 conditional cases are resolved and neither enters: Iowa's ISASP workbooks carry no district-by-race rows (IA 2022-2025), and Arkansas 2022, added and downloaded 2026-09-15, carries race at state level only, its district sheet being all students. Both stay archived as the record of the check. Reference tables drafted (2026-09-16, author to check): `test_replacement.csv` extended to end year 2025 (816 rows; the 204 new rows have `author_check` blank; data acquisition 3.2), and `data/reference/hs_reportcard_harmonization.csv` built, one row per manifest state-year (162: 152 mapped, 10 unavailable). New York Access exports (2026-09-16): `R/02a_ny_access_export.R`, run in the project container with mdbtools 1.0.0, writes table `[Annual Regents Exams]` of each SRC zip's `.mdb` to `data/raw/hs_reportcards/NY/SRC<yyyy>_annual_regents_exams.csv`, archived and checksummed as `hs_reportcard_ny_src_csv` 2022-2025 with the command in `notes`; CCD school characteristics for end years 2022-2024 added and archived (CEP for step 12). Still to add: F-33 fiscal year 2025 if published. Not yet in an OSF deposit |
| 11 (run 2) | `R/11_seda_outcomes.R` — SEDA grades 3–8 gaps, extension design Sections 5, 6 | Claude Code | **complete, commit fb3084d**; complete (2026-09-16): `data/derived/seda_gaps.csv` (never deposited, data use agreement), one row per gap and unit-year, `v` = mean of math and RLA, both required; grade 3–8 pooling on SEDA's unadjusted SEs, rules 1–2 over 2010–2019 and 2022–2024, gap (a) quintiles among districts with a 2009–10 span including a grade 3–8 (docs/deviations_run2.md, 2026-09-16); BIE units (prefix 59) dropped with the rest outside the 50 states and DC |
| 12 (run 2) | `R/12_hs_reportcard_outcomes.R` — high school report-card gaps 2022–2025, extension design Sections 4–6 | Claude Code | **complete, commit f9f5de3**; complete (2026-09-16, commit f9f5de3): one loader per state (`R/functions/hs_reportcard_loaders.R`) for the 152 mapped state-years; `data/derived/hs_panel_run2.csv` (Run 1 sample file plus 40,643 report-card district-years, `source`) and `data/derived/hs_gaps_run2.csv`; the nine step 12 decisions in docs/deviations_run2.md (2026-09-16); Vermont 2022-2025 do not enter (supervisory-union reporting fails rule 1; union results not mapped onto member districts; docs/deviations_run2.md, 2026-09-16); `data/reference/hs_reportcard_leaid_crosswalk.csv` drafted (10,221 code matches, 306 name matches for NH, RI, UT, WY, 64 unmatched or ambiguous; author_check blank) and harmonization columns `subgroup_all`, `participation_col`, `min_group_size`, `min_group_source` drafted, author to check; `readxl` and `readxlsb` (GitHub, pinned) in `renv.lock`, image `finance-reform-study:run2-step12` restores them; `--reuse-long` resumes from `data/derived/hs_reportcard_long_parts/` |
| 13 (run 2) | `R/13_continuous_did.R` — continuous treatment, `DIDmultiplegtDYN` 2.4.0, extension design Section 7 | Claude Code | **complete, commit 1c47628**; complete (2026-09-16, commit 1c47628): revenue bins of 1,000 (2,000 sensitivity) in 2025 dollars, switch = bin leaves its baseline bin; the binned revenue enters as a discrete treatment (switchers matched to stayers of the same baseline bin; `continuous = 1` exceeds this machine's memory at any usable number of effects) and without controls (the covariate-by-year controls also exceed memory); 16 models (high school, SEDA, graduation gaps x two bin widths), each fitted in a child R process, estimates, switchers and stayers per effect and placebo, switchers dropped for no stayer in their bin, and the 20-stayers-in-3-states rule in `outputs/run2/13_continuous/`; `--counts-only` skips the fits; decisions in docs/deviations_run2.md (2026-09-16); `polars` pinned to r-universe commit 08ba079 in `renv.lock` |
| 14 (run 2) | `R/14_run_all_run2.R` — full run and reporting, extension design Section 12 | Claude Code | **complete, commit 995c2b7 (tag `freeze-run2` at a77c9ce)**; **full run on the REAL tables complete** (code at tag `freeze-run2`, commit a77c9ce; run 20260917T041717Z, 14.01 h over parts, wall clock 14.02 h; 2026-09-17), from a clean start with no code change: steps 5-7 on both Run 2 outcome families at the registered counts, the variants and Section 10 splits, Lee bounds, dose scaling, the descriptive SEDA MDE and `outputs/run2/13_report/` (5 plots, 62 tables); the report showed 9 models with their recorded status in place of numbers; `--resume` continues an interrupted run, `--report` rebuilds the report; `tests/run_tests.R` passes. **Post-freeze correction (2026-09-17, docs/deviations_run2.md, Section 7)**: the Callaway–Sant'Anna models of the high school family no longer take the source covariate `rc_first`, whose report-card-only units have no pre-2022 rows, leaving the doubly robust estimator singular in every 2x2 that reaches before 2022 — it had left high school gap (b) unweighted on the unbalanced panel with no estimable cell and gap (c) with two cohorts. The high school family alone was refitted at the registered counts (steps 5-7, the variants and splits, Lee bounds and dose scaling; 19.32 h over parts, finished 2026-09-18); SEDA is untouched, the EDFacts-years split still reproduces Run 1 exactly, 18 further variant models now fit, and the rebuilt report shows 6 plots, 62 tables and 0 models with a status in place of numbers. **Post-freeze correction (2026-09-18, docs/deviations_run2.md, Section 7): treated-unit floor** — in gaps (b) and (c) of both families a cohort with fewer than 20 treated units at its base period in the primary panel is left out of every Callaway–Sant'Anna model of its gap and event set (step 5, variants and splits, Lee, dose; `run2_model_panel(cohort_floor = TRUE)`) and fitted without covariates in `outputs/run2/13_report/appendix/thin_cohorts.csv` (every cohort's count in `appendix/cohort_floor.csv`); step 6 unchanged; the event-study tables mark with † a coefficient on a single treated state. Removed on the primary event set: 2017 (SD), 2019 (NM), 2020 (NV), 2025 (CO, MS) in both gaps and families, plus 2022 (MD, OH; 19 districts in 2021) in high school gap (c); on r2, 2019 (NM); none on r1. The gap (b)/(c) models of the primary and r2 sets were refitted in both families at the registered counts (steps 5 and 7, variants, Lee, dose, SEDA MDE; 11.89 h over parts, finished 2026-09-19 02:06 UTC), gap (a) and r1 reused; report rebuilt with `--report` (6 plots, 62 tables, 0 models with a status in place of numbers); `tests/run_tests.R` passes |

**Status (2026-09-19): the study is complete. Run 1 and Run 2 are both deposited; every file, with the hash file, is at the same DOI, https://doi.org/10.17605/OSF.IO/6FDVY.**

## Decisions already made (do not reopen)

- Design v18 governs (`docs/design.md`, commit `a263a49`, with the deviations in
  `docs/deviations.md`). It adds one secondary outcome family: the within-district
  Black–White and Hispanic–White gaps in the four-year adjusted cohort graduation
  rate (EDFacts LEA files), as V under the Section 5 rules (30 on the cohort count,
  range midpoints for ranges of 10 points or less, exact-only and 5-point samples),
  on the same event sets, estimators, inference and reporting as the primary gaps,
  reported after them, with no power calculation. As implemented (author,
  2026-09-12; docs/deviations.md; data acquisition 5.2): end years 2011–2021;
  `R/03g_graduation_sample.R`, `R/04g_graduation_outcomes.R`, then steps 5–7 with
  `--outcome graduation` (outputs in `graduation/` subfolders); rules 1–2 over
  2010–2021 with `LEA_TYPE`/`UPDATED_STATUS` for `TYPE`/`BOUND` from 2014-15;
  rule 6 from the event tables' groups unchanged; weight = 2010-11 cohort count in
  the gap's two groups (`cohort_2011`); regression controls = CEP (district-year)
  and the 2009 covariates by year, no test-replacement flag; step 6 on all three
  event sets; Romano–Wolf family = the two graduation gaps.
- Reform list: LRS (2018) list for 1990–2011. After Dec 31, 2011 two written
  rules: court rule (ruling holding the K–12 finance system or operating-aid
  formula unconstitutional that became final: unappealed or affirmed; vacated
  or reversed rulings do not count) and statute rule (statute that enacted a
  new primary operating-aid formula replacing the one in force; parameter
  amendments and supplemental programs do not count). Coding table deposited
  before outcome downloads. Event files: lrs_events.csv,
  court_events_after_2011.csv, legislative_events_after_2011.csv.
- Three event sets, all permuted during development: `event_table.csv`
  (full, primary), `event_table_r1.csv` (LRS + final supreme court rulings),
  `event_table_r2.csv` (court events only). Steps 5–7 run on all three; the
  full set is primary and r1/r2 are reported as robustness (design Section 3).
- Window: end years 2010 through the newest EDFacts release on the
  registration date; 2020 excluded; 2021 kept only where participation ≥ 95%.
- Registration end year (author, 2026-09-11; docs/decision_log.md, Section 3): **2021**
  (school year 2020–21), the newest school year with LEA-level EDFacts achievement files
  for both mathematics and reading/language arts. SY2021–22 carries the LEA
  reading/language arts file only; SY2022–23 onward carries no LEA assessment file. ED
  publishes the assessment files in the ED Data Library
  (`https://eddataexpress.ed.gov/download/data-library`); the legacy
  `www.ed.gov/sites/ed/files/.../data-files/` names serve end years 2013–2018 and 2021
  but not 2019, which step 2's manifest pattern will need a different URL for.
- Graduation window (author, 2026-09-12; docs/deviations.md, Section 3): end
  years **2011 through 2021**, not 2024. LEA-level adjusted cohort graduation
  rate files exist only through 2020–21; the ED Data Library's 2022–23 and
  2023–24 graduation listings are state level, which cannot form a
  within-district gap. 2020 is included for the graduation outcome only — the
  Section 3 exclusion of 2019–20 covers the waived assessments, and graduation
  rates were reported that year. Reforms after 2020 have no post-reform years
  in either outcome and stay not-yet-treated controls.
- Sample: regular districts (CCD types 1–2); stable ID; exact counts;
  percent proficient exact or a range midpoint (suppression rule below);
  tested count ≥ 30 per cell; 95% participation; treatment at state level;
  reforms in 2005–2009 exclude the state; early cohorts kept, with cohort
  counts reported per event time and a robustness check dropping cohorts
  with fewer than three pre-years.
- Participation rule (design v17, Section 5): EDFacts participation files
  begin with 2012–13, so the 95% rule applies from 2012–13 onward;
  2009–10 through 2011–12 are retained without the participation test, and
  a robustness check restricts the sample to 2012–13 onward.
- Assessment flag: test replacements only. Table
  `data/reference/test_replacement.csv` (data acquisition 3.2): the 50 states
  plus DC, no PR, BIE, or VI; stage 1 is end years 2010–2013, 204 rows.
  Columns: state, sy_end, replaced_math, replaced_rla, replaced,
  assessment_math, assessment_rla, source, evidence, notes. Subjects are coded
  separately; replaced = 1 if either is 1. A subject is 1 in the first school
  year in which its EDFacts high school result comes from the new test. A test
  rebuilt for new standards with a new scale is a replacement even if the name
  is unchanged; a new cut score on an unchanged test is 0. A change in which
  instrument is reported (e.g. augmented SAT to SAT alone) is 1. A year that mixes
  old and new results is flagged. Every row is coded from the state education
  agency's assessment history page (Wayback Machine copies allowed, cited with
  the archived URL and capture date); the state's ESEA flexibility request
  (label "ESEA flexibility request", kept distinct from SEA pages), ESEA
  accountability workbook, or ESSA plan comes third. The EDFacts
  "significantly changed" lists are pointers
  only. Documented rows get evidence = documented; a state-year with no
  documented change is 0 with evidence = inferred. Wyoming 2009–10 keeps a row
  coded from the test administered, with a note about the invalidated results.
- Outcome: probit gap V from single-cut proficiency shares. No multi-level data.
- Gaps (b) and (c): unweighted primary; tested-count weighted robustness.
- CS estimator with not-yet-treated controls, event time −5..+8, reference −1,
  doubly robust, pre-treatment covariates only.
- Inference: state clusters; wild cluster bootstrap, Webb weights, 9,999 reps;
  RI 10,000; Romano–Wolf 9,999; HonestDiD relative magnitudes on the overall
  post average, M̄ ∈ {0, 0.5, 1, 1.5, 2}.
- CPI-U all items, July–June school-year average, base = last window year.
- Missing CPI month (design v17, Section 7): filled with the mean of the two
  adjacent months.
- Author decisions made before registration are logged in
  docs/decision_log.md (date, section, decision, rationale). docs/deviations.md
  holds departures from the registered design after filing.
- Sample rules as implemented (author, 2026-09-11; data acquisition 4.1):
  participation by the band rule below; poverty quintiles fixed per
  state among districts passing rules 1–2 with a 2009–10 grade span to 12 and
  a SAIPE 2009 rate; stability = CCD BOUND not 2, 6, or 7 in every window year
  and never 5 or 8, agency type 1–2 in every year.
- Participation bands (author, 2026-09-11; replaces the lower-bound reading;
  data acquisition 4.1; docs/decision_log.md): the 95% test applies to the
  exact value where one is reported and to the band midpoint where
  participation is banded (printed endpoints, as in the suppression rule):
  GE90 (95) passes, 90-94 (92) and lower bands fail, nothing reported fails.
  The exact-only sample keeps exact participation values; its cells report
  participation exactly or as GE99, which passes, so one `part_ok_*` flag
  serves all three samples. Rationale: the same logic as the midpoint rule,
  and it reduces the 2012-to-2013 discontinuity in sample composition rather
  than removing it. The effective threshold depends on district size: 31–60
  tested pass on GE90, 61–300 fail at 90-94, and only the largest districts
  face the literal 95.
- Suppression rule (author, 2026-09-11; replaces exact-only; data acquisition
  4.1; docs/decision_log.md): the valid-test count must be exact and
  ≥ 30. Percent proficient enters as the exact value or, when reported as a
  range no wider than 10 percentage points, at the range midpoint; wider
  ranges and suppressed values (PS, N/A, blank) are missing. Width and
  midpoint come from the printed endpoints, with GE/GT closed at 100 and
  LE/LT at 0 (20-29: width 9, midpoint 24.5; GE95: width 5, midpoint 97.5;
  an exact value: width 0). Two robustness samples: exact values only, and
  ranges of 5 points or less (`MAX_WIDTH`, `cell_in_sample()`). The sample
  file carries each cell's width (`w_*`) and entering percent (`p_*`) for
  step 4. Rationale: the exact-only rule left about 200 district-years per
  subject-year for gaps (b) and (c), all in the largest districts; a range
  midpoint is measurement error in the outcome, bounded at half the range
  width and unrelated to treatment, which does not bias a DiD estimate and
  only widens its interval. The error is not classical (it depends on where
  the true rate sits in its band and is larger in probit units at the
  tails), so the no-bias claim is approximate; the exact-only and 5-point
  samples are the check.
- SAIPE (author, 2026-09-11; docs/decision_log.md): districts passing
  rules 1–2 with no SAIPE 2009 child-poverty rate (absent from the file, or no
  children 5–17) are dropped for all gaps.
- CCD BOUND 8 (reopened) is a change code like 5 (author, 2026-09-11): a code
  8 in any window year excludes the district.
- Gap (a) weight (author, 2026-09-11; docs/decision_log.md): each district's
  total membership in the 2009–10 CCD LEA file (`MEMBER`), fixed across
  years. Pre-treatment; matches the 2009 enrollment covariate (Section 7).
  A district without a valid 2009–10 membership (−1, −2, −9, or 0) is left
  out of gap (a) and stays in (b) and (c): four CA quintile-5 districts
  coded −9 in stage 1.
- Gap sign (author, 2026-09-11; docs/decision_log.md): V is Black − White and
  Hispanic − White, the same orientation as gap (a) (top-poverty minus
  bottom-poverty quintile). Gaps are usually negative; a positive effect means
  the gap narrowed. Reardon's convention is the reverse.
- Outcomes as implemented (author, 2026-09-11; data acquisition 4.2): step 4
  takes counts and `p_*`/`w_*` from `sample_district_year.csv`, divides
  percentages by 100, and calls `v_gap()`/`v_gap_se()`; all three
  suppression samples, named in a `sample` column. A gap uses a
  district-year-subject only when both subgroups pass rule 3 and, from
  2012–13, rule 4. Rows carry `retained`, `retained_r1`, `retained_r2`. A
  gap (a) state-year without a usable district in quintile 1 or 5 gets no
  row (DC and HI never do). Standard errors cover binomial sampling only.
- Primary estimator as implemented (author, 2026-09-11; docs/decision_log.md):
  outcome = mean of math and RLA V per unit-year, both subjects required;
  unbalanced panel (`allow_unbalanced_panel = TRUE`), with the balanced panel
  as a robustness model — every model is fitted under both rules and the
  `panel` column (`unbalanced` primary, `balanced` robustness) names which,
  so the model key is `gap.event_set.weighting.panel` and step 5 writes 30
  models; `did::att_gt` with not-yet-treated
  controls, DR, universal base period, state clusters (did multiplier
  bootstrap, defaults); `aggte` dynamic −5..+8 and its overall post average.
  Covariates for (b) and (c): log 2009–10 CCD `MEMBER`, SAIPE 2009 rate,
  Black and Hispanic shares of 2009–10 CCD school membership; none for (a).
  The test-replacement and CEP flags are not in the CS models (did takes
  baseline covariates only). Tested-count weight: 2009–10 count in the gap's
  two groups, mean of math and RLA, fixed; on the unbalanced panel a district
  with no 2009–10 row has no such weight and is left out of the weighted
  models alone (`dropped_missing_weight`). States treated after the window
  are not-yet-treated controls (g = 0); states treated in the first window
  year have no pre-period and cannot enter.
- Secondary estimators on the unbalanced panel (author, 2026-09-13; docs/deviations.md,
  Section 7): Sun–Abraham, imputation, stacked and the TWFE rows run on the step 5
  unbalanced panel (main step 6 files); synthdid stays at the state level on state-year
  means of the unbalanced panel, states with a mean in every window year only; the
  balanced-panel versions go to `outputs/06_secondary/appendix/`. This replaces the
  balanced-panel statement in the entry below.
- Secondary estimators as implemented (author, 2026-09-11; docs/decision_log.md):
  the step 5 balanced panels, unweighted, primary event set only (the step 6
  instruction; `EVENT_SETS` takes r1 and r2). They stay on the balanced panel
  because synthdid needs a rectangular state-by-year matrix and Section 7 gives
  no rule for an unbalanced one, so the Section 13 agreement table compares an
  unbalanced primary with balanced secondaries and step 5's balanced robustness
  models are the like-for-like comparison — awaiting the author's confirmation. Controls in the regression
  estimators: test_replaced and cep for every gap, plus the four 2009 covariates
  interacted with year for (b) and (c) (stacked: with sub-experiment-by-year).
  synthdid: state level, cohort by cohort, no controls, placebo SEs; a cohort
  with fewer than two pre-reform years is left out, which in stage 1 leaves one
  cohort per gap. Stacked: event times −5..+5, clean controls through g+5,
  corrective weights, sub-experiments not trimmed to complete windows (rule 6
  keeps early cohorts). Overall = mean of the event-time estimates 0..+8; static
  TWFE is its own row. Sun–Abraham uses the sunab cohort-by-period indicators
  built in `sa_terms()`: fixest 0.14.2's `sunab()` drops a cohort whose treated
  units supply one pre-treatment observation, which is gap (a) — awaiting the
  author's confirmation.
- Inference as implemented (author, 2026-09-11; docs/decision_log.md): all four
  procedures of Section 8 run on the 30 step 5 models (both panel rules). The Webb wild cluster bootstrap
  and the Romano–Wolf step-down run on did's influence function summed within state,
  not through `fwildclusterboot` and `wildrwolf`, which take an lm or fixest object and
  cannot test an average of group-time effects. One set of state-level Webb draws per
  event set serves every model in it, so Romano–Wolf's unadjusted p-value is by
  construction the bootstrap's. Romano–Wolf family: the three gaps within one event set, weighting
  family and panel rule (the step-down compares hypotheses fitted on the same
  data), once unweighted and once with the weighted (b) and (c). RI reassigns the observed
  cohort years among every state in the panel, keeping the states per cohort year, and
  refits; the reassignments are drawn in the parent process, so the result does not
  depend on the worker count. HonestDiD relative magnitudes on the overall post average
  with `l_vec` equal over the estimated post event times; a model with no estimated
  pre-reform event time gets a status, not a bound (in stage 1, every r2 model), and an
  M̄ whose grid search accepts nothing is recorded as an empty bound set.
  `Rscript R/07_inference.R --quick` is a test run at reduced counts; the counts of a
  run are recorded in `outputs/07_inference/inference_settings.csv`.
- Power: 2,000 placebo runs on 2010–2013; report the MDE at 80% power.
- Power as implemented (author, 2026-09-11; docs/decision_log.md): the three primary
  gaps of the primary event set, unweighted, each on its step 5 estimation panel (the
  primary, unbalanced one); 2,000 placebo runs per gap in each of four scenarios, every
  draw made in the parent process so no result depends on the worker count.
  `six_state` (`seed_for("power_6")`, `mde_6states.csv`, `SIX_STATES`): six
  placebo-treated states, cohort years drawn uniformly from 2011–2013. This is the
  registered power calculation and the 0.10 SD rule is applied to it alone; six is the
  treated states the event table carries with post-reform data by the registration end
  year 2021 (`REG_END`), which the script checks and warns about if it differs.
  Sensitivity runs: `twelve_state` (`seed_for("power_12")`, `mde_12states.csv`) and
  `ten_state` (`seed_for("power_10")`, `mde_10states.csv`), both made while the end year
  was still assumed to be 2025 — twelve is the treated-state count under that assumption,
  ten the count assumed before it — and `observed` (`seed_for("power")`, `mde.csv`):
  treated states drawn from every state in
  the panel and given the observed cohort years (the Section 8 reassignment); in stage 1
  that is two treated states, the pre-period's own cohort count, so that run is
  descriptive of the pre-period. MDE = the smallest shift of the placebo distribution
  that a test at the 95th percentile of the absolute placebo estimates rejects with
  probability 0.80; the normal-approximation figure (2.8016 x sd) is reported beside it.
  Stage 1: 0.182, 0.168 and 0.154 SD six-state, 0.152, 0.128 and 0.122 twelve-state,
  0.156, 0.143 and 0.137 ten-state, 0.225, 0.300 and 0.245 observed, for gaps (a), (b),
  (c). The ceiling is exceeded for
  all three gaps in the registered run, so on the stage 1 files Section 10's criterion
  READS UNDERPOWERED — the balanced panel kept gap (c) under it, and the switch to the
  unbalanced panel widened the placebo distribution. `mde_6states.csv`,
  `mde_10states.csv` and
  `mde_12states.csv` also carry a supplementary `mde_projection` column (square root of
  the post-reform state-year ratio, registration end year 2021, 2020
  left out): 0.117, 0.108 and 0.099 SD at six states, against the registered window's
  29 post-reform state-years. It is not the power calculation and is kept off the console
  because it summarises the event table's cohort years. `--quick` is a test run at a
  reduced count, recorded in `outputs/08_power/power_settings.csv`.
- Environment lock (author, 2026-09-13): `fwildclusterboot`, `wildrwolf`, `summclust`
  and `testthat` stay out of `renv.lock`. They appear in `outputs/package_versions.csv`
  because they were installed, but no script uses them: the wild cluster bootstrap and
  Romano–Wolf are computed on the did influence function.
- Step 10 as implemented (author, 2026-09-13; docs/deviations.md): the lawsuit-filing-date
  version is replaced by `did`'s `anticipation = 1` (reference −2); Section 5/7 robustness
  checks run one departure at a time from the primary specification on all three event
  sets and both weightings (`VARIANTS`, `R/functions/run_all.R`), with bootstrap and
  Romano–Wolf at 9,999, HonestDiD at every M̄, randomization inference at 1,000 (compute
  deviation; step 5 models keep 10,000 in step 7); Lee bounds for gaps (b) and (c) only,
  tested share over CCD grade 9 membership three years earlier, differential trim fraction
  |p_minority − p_White| with p_g = 1 − q_C,g / q_T,g (q_C = q_T − the CS effect on the
  share), bounded to [0, 1], applied to the treated post-reform district-years from the top
  and from the bottom (2026-09-14; the control-group rule is withdrawn), share years from 2010 (CCD school files for end years 2007–2009
  added 2026-09-14; 2006-07 is fixed-width with a separate layout); dose scaling = ratio of
  the CS overall effect on the gap to that on (TSTREV + TLOCREV) / V33 in thousands of 2021
  dollars (gap (a): the quintile 5 − quintile 1 revenue gap), excluding district-years with
  V33 below 30 or revenue above $100,000 per pupil (2026-09-14), percentile interval from
  step 7's Webb draws,
  "unbounded" when the revenue interval includes zero; M̄ = 1 is the headline bound set;
  graduation gets every Section 13 item but Lee bounds. Achievement step 6 now runs on all
  three event sets. `R/10_run_all.R` sets `RENV_CONFIG_SANDBOX_ENABLED=FALSE` for the
  processes it starts: under renv, 12 workers starting together deadlock on renv's sandbox
  lock and leave it stale (`~/AppData/Local/R/cache/R/renv/sandbox/.../*.lock`; delete it
  if R hangs at startup and no R process is running).
- HonestDiD grid (code correction, 2026-09-14; docs/deviations.md): `honest_rm()` widens
  HonestDiD's default grid (±20 sd, 1,000 points) on any side a bound set reaches, at the
  same step, up to 6 times, and records the grid on each row; no reported bound set touches
  a grid edge. `Rscript R/07_inference.R --honest-only [--outcome graduation]` recomputes
  the bound sets from the step 5 fits without rerunning the bootstrap or randomization
  inference, writing `honestdid_grid_change.csv` beside them.
- License: MIT.
