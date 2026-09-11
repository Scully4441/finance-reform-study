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
5. Never edit `docs/design.md`. Record any departure in
   `docs/deviations.md` with date and reason.
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

## Run order

| Step | Script | Who runs it | Status |
|---|---|---|---|
| 0 | `R/00_install_packages.R` | Claude Code | |
| 1 | `R/01_build_event_table.R` | author, plain terminal | |
| 2 | `R/02_download.R` (stage 1 rows of the manifest) | Claude Code | complete (2026-09-11) |
| 3 | `R/03_sample.R` — sample rules, design Section 5 | Claude Code | complete (2026-09-11); range midpoints (2026-09-11) |
| 4 | `R/04_outcomes.R` — gaps (a) (b) (c), design Section 6 | Claude Code | |
| 5 | `R/05_primary.R` — Callaway–Sant'Anna, design Section 7 | Claude Code | |
| 6 | `R/06_secondary.R` — four secondary estimators | Claude Code | |
| 7 | `R/07_inference.R` — bootstrap, RI, Romano–Wolf, HonestDiD, Section 8 | Claude Code | |
| 8 | `R/08_power.R` — placebo simulation on 2010–2013, Section 10 | Claude Code | |
| — | Author files the OSF registration; sets `data/stage.txt` to `2` | author | |
| 9 | `R/09_unblind.R` after `git tag -a freeze` | author, plain terminal | |
| 10 | `R/10_run_all.R` — full run and reporting, Section 13 | Claude Code | |

Update the Status column as steps finish.

## Decisions already made (do not reopen)

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
- Sample rules as implemented (author, 2026-09-11; data acquisition 4.1):
  participation passes when the reported value's lower bound is ≥ 95 (GE95
  passes, GE90 fails, nothing reported fails); poverty quintiles fixed per
  state among districts passing rules 1–2 with a 2009–10 grade span to 12 and
  a SAIPE 2009 rate; stability = CCD BOUND not 2, 6, or 7 in every window year
  and never 5 or 8, agency type 1–2 in every year.
- Suppression rule (author, 2026-09-11; replaces exact-only; data acquisition
  4.1; logged in docs/deviations.md): the valid-test count must be exact and
  ≥ 30. Percent proficient enters as the exact value or, when reported as a
  range no wider than 10 percentage points, at the range midpoint; wider
  ranges and suppressed values (PS, N/A, blank) are missing. Width and
  midpoint come from the printed endpoints, with GE/GT closed at 100 and
  LE/LT at 0 (20-29: width 9, midpoint 24.5; GE95: width 5, midpoint 97.5;
  an exact value: width 0). Two robustness samples: exact values only, and
  ranges of 5 points or less (`MAX_WIDTH`, `cell_in_sample()`). The sample
  file carries each cell's width (`w_*`) and entering percent (`p_*`) for
  step 4.
- SAIPE (author, 2026-09-11; logged in docs/deviations.md): districts passing
  rules 1–2 with no SAIPE 2009 child-poverty rate (absent from the file, or no
  children 5–17) are dropped for all gaps.
- CCD BOUND 8 (reopened) is a change code like 5 (author, 2026-09-11): a code
  8 in any window year excludes the district.
- Power: 2,000 placebo runs on 2010–2013; report the MDE at 80% power.
- License: MIT.
