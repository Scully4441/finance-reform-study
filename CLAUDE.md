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

## Run order

| Step | Script | Who runs it | Status |
|---|---|---|---|
| 0 | `R/00_install_packages.R` | Claude Code | |
| 1 | `R/01_build_event_table.R` | author, plain terminal | |
| 2 | `R/02_download.R` (stage 1 rows of the manifest) | Claude Code | complete (2026-09-11) |
| 3 | `R/03_sample.R` — sample rules, design Section 5 | Claude Code | complete (2026-09-11); range midpoints (2026-09-11) |
| 4 | `R/04_outcomes.R` — gaps (a) (b) (c), design Section 6 | Claude Code | complete (2026-09-11) |
| 5 | `R/05_primary.R` — Callaway–Sant'Anna, design Section 7 | Claude Code | complete (2026-09-11); unbalanced panel primary, balanced panel robustness (2026-09-11) |
| 6 | `R/06_secondary.R` — four secondary estimators | Claude Code | complete (2026-09-11), primary event set, step 5 balanced panels |
| 7 | `R/07_inference.R` — bootstrap, RI, Romano–Wolf, HonestDiD, Section 8 | Claude Code | complete (2026-09-11), 30 models; run so far only at the reduced `--quick` counts |
| 8 | `R/08_power.R` — placebo simulation on 2010–2013, Section 10 | Claude Code | complete (2026-09-11); observed-cohort, ten-state and twelve-state runs |
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
  primary, unbalanced one); 2,000 placebo runs per gap in each of three scenarios, every
  draw made in the parent process so no result depends on the worker count.
  `twelve_state` (`seed_for("power_12")`, `mde_12states.csv`, `TWELVE_STATES`): twelve
  placebo-treated states, cohort years drawn uniformly from 2011–2013. This is the
  registered power calculation and the 0.10 SD rule is applied to it alone; twelve is the
  treated states the event table carries with post-reform data by 2025, which the script
  checks and warns about if it differs. Sensitivity runs: `ten_state`
  (`seed_for("power_10")`, `mde_10states.csv`, ten states, the earlier count) and
  `observed` (`seed_for("power")`, `mde.csv`): treated states drawn from every state in
  the panel and given the observed cohort years (the Section 8 reassignment); in stage 1
  that is two treated states, the pre-period's own cohort count, so that run is
  descriptive of the pre-period. MDE = the smallest shift of the placebo distribution
  that a test at the 95th percentile of the absolute placebo estimates rejects with
  probability 0.80; the normal-approximation figure (2.8016 x sd) is reported beside it.
  Stage 1: 0.152, 0.128 and 0.122 SD twelve-state, 0.156, 0.143 and 0.137 ten-state,
  0.225, 0.300 and 0.245 observed, for gaps (a), (b), (c). The ceiling is exceeded for
  all three gaps in the registered run, so on the stage 1 files Section 10's criterion
  READS UNDERPOWERED — the balanced panel kept gap (c) under it, and the switch to the
  unbalanced panel widened the placebo distribution. `mde_10states.csv` and
  `mde_12states.csv` also carry a supplementary `mde_projection` column (square root of
  the post-reform state-year ratio, registration end year 2025 as a placeholder, 2020
  left out): 0.090, 0.076 and 0.072 SD at twelve states, against the registered window's
  68 post-reform state-years. It is not the power calculation and is kept off the console
  because it summarises the event table's cohort years. `--quick` is a test run at a
  reduced count, recorded in `outputs/08_power/power_settings.csv`.
- License: MIT.
