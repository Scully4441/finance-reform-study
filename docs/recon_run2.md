# Run 2 reconnaissance: SEDA, SEA files, estimator

Checked 2026-09-15 by Claude Code. No data file was downloaded. Only repository
metadata, documentation (the SEDA 2025.2 technical documentation PDF and district
codebook), web listing pages and an R package were fetched. Nothing here changes
`docs/design.md`, the pipeline or `renv.lock`; the package test used a throwaway
library outside the project (`%TEMP%\rdyn`).

## 1. Stanford Education Data Archive (SEDA)

### Newest release

**SEDA 2025.2**, issued 2026-08-31 (repository key date 2026-09-01).
Citation: Reardon, Fahle, Ho, Shear, Saliba, Min, Shim & Kalogrides (2026),
Stanford Education Data Archive (Version SEDA 2025.2),
<https://purl.stanford.edu/np279jm6134>, DOI `10.25740/np279jm6134`.
It replaces SEDA 2025.1 (`10.25740/hm970gr1371`). 2025.2 uses EDC SADR v3.1, which has
updated data for 15 states, and adds gap estimates for states and administrative districts.

### School years at the district level

Documentation p. 4: grades **3–8**, math and RLA, school years **2008-09 through
2018-19 and 2021-22 through 2024-25** (end years 2009–2019 and 2022–2025). There is
**no 2019-20 or 2020-21** (end years 2020, 2021). The district unit is the
*administrative* district (`sedaadmin`, a 7-digit NCES LEAID including charters).
SEDA 5.0/6.0 geographic-district files are not carried forward.

Sources by period (documentation pp. 8–9):
- 2009–2019: EDFacts school-level non-suppressed counts (restricted-use; no minimum cell).
- 2022–2025: EDC State Assessment Data Repository v3.1, i.e. **public, suppressed**
  state-reported data, then cleaned. Some states report no tested counts or no subgroups.

Earlier "recovery" releases, from the edopportunity.org downloads page:

| Release | Persistent URL | Coverage (district level) |
|---|---|---|
| SEDA 2025.2 | purl.stanford.edu/np279jm6134 | 2009–2019, 2022–2025; schools, admin districts, states |
| SEDA 2025.1 | purl.stanford.edu/hm970gr1371 | same span, superseded |
| SEDA 2024.3 | purl.stanford.edu/wh992dd5709 | 2019–2024 admin districts and states; long / annual / annualsub; CS, YS, GCS, GYS |
| SEDA 2024.2 | purl.stanford.edu/ns863bk0785 | 2019–2024, superseded |
| SEDA 2024 (2024.1) | purl.stanford.edu/pt329xg7054 | 2019–2024, superseded |
| SEDA 2023 | purl.stanford.edu/xt779fj2637 | changes 2019→2022, 2022→2023, 2019→2023; pooled by year and subject; YS, GYS, NAEP scales only |
| SEDA 2022 2.0 | purl.stanford.edu/dt080zr0625 | 2019 and 2022 levels and change; YS, GYS, NAEP |
| SEDA 2022 | purl.stanford.edu/jm728cq7283 | 2019 and 2022, subset of states; YS, GYS, NAEP |

The 2022 and 2023 releases have no by-grade long files on the CS/GCS scales. The 2024.x
releases have long files for 2019–2024 only. 2025.2 is the only release that has
2009–2019 and 2022–2025 in one set of files.

### Files with district × year × grade × subject means and SEs

The **long** files. There is one per scale, each in CSV and Stata. Sizes are in bytes,
from the repository's contentMetadata (`purl.stanford.edu/np279jm6134.xml`):

| File | Scale | Size (bytes) |
|---|---|---|
| `seda_admindist_long_cs_2025.2.csv` | CS | 1,026,013,873 |
| `seda_admindist_long_cs_2025.2.dta` | CS | 989,020,250 |
| `seda_admindist_long_gcs_2025.2.csv` | GCS | 1,020,858,017 |
| `seda_admindist_long_gcs_2025.2.dta` | GCS | 989,020,250 |
| `seda_admindist_long_ys_2025.2.csv` | YS | 1,025,783,105 |
| `seda_admindist_long_ys_2025.2.dta` | YS | 989,020,250 |
| `seda_admindist_long_gys_2025.2.csv` | GYS | 1,020,870,364 |
| `seda_admindist_long_gys_2025.2.dta` | GYS | 989,020,250 |
| `seda_codebook_admindist_2025.2.xlsx` | codebook | 94,655 |
| `SEDA_documentation_2025.2.pdf` | documentation | 1,080,259 |
| `seda_cov_admindist_long_2025.2.csv` / `.dta` | covariates, by grade-year | 785,560,604 / 715,215,212 |
| `seda_crosswalk_2025.2.csv` / `.dta` | school–district crosswalk | 32,851,173 / 50,843,970 |

The deposit has 122 files in total. The others are the annual, annualsub, pool and poolsub
aggregations for districts, schools and states, plus covariates and codebooks.

**Layout** (codebook sheets `seda_admindist_long_cs` and `_gcs`, 106 variables). There is
one row per `sedaadmin` × `subject` × `grade` × `year`, and subgroups are **columns**:
`sedaadmin, sedaadminname, subject, grade, year, fips, stateabb`, then for each subgroup
`tot_asmt_<g>`, `flag_estasmt_<g>`, `<scale>_mn_<g>`, `<scale>_mn_se_<g>` and
`<scale>_mn_se_adj_<g>`, plus `multi_comp_<g>`.
- All students: `gcs_mn_all`, `gcs_mn_se_all`, `gcs_mn_se_adj_all` (CS: `cs_mn_all`, ...).
- Black: `*_mn_blk`, `*_mn_se_blk`. Hispanic: `*_mn_hsp`, `*_mn_se_hsp`. White: `*_mn_wht`, `*_mn_se_wht`.
- Gap columns computed by SEDA: `*_mn_wbg` (White−Black), `*_mn_whg` (White−Hispanic).
  They are **White minus minority**, the reverse of this project's sign convention.
- `_se_adj` adds NAEP linking error. For within-district subgroup differences the
  adjusted and unadjusted SEs are identical (documentation p. 52).

**Scale.** All four scales are published as separate files, so CS and GCS are both available.
CS = SD units of the national grade-subject distribution for the cohorts in 4th grade in
2009/2011/2013/2015. GCS = grade levels relative to the same cohorts (4 = national grade-4
mean). YS/GYS standardize to the 2019 national distribution (pp. 36–37). The website shows GYS.

### Minimum cell size and other exclusions (long files)

- **At least 20 unique students** per unit-subgroup-subject-grade-year estimate, a condition
  of the ED agreement. It is applied to the 2022–2025 EDC-based estimates too (Step 12, pp. 52–53).
- 2009–2019 long-file estimates carry added noise ~ N(0, ω̂²/n), and their SEs are adjusted
  for it. 2022–2025 estimates have no added noise.
- Estimates with CS-scale SE > 1 are removed. All subgroup estimates are suppressed when
  the all-students mean is missing.
- Participation: unit-subgroup-subject-grade-year cases with participation < 94% are dropped,
  and so are state-subject-grade-years outside 94–105%. Cases with representation below 95%
  are also dropped. Participation is tested from 2012-13 on and in 2022–2025 where states
  report it (pp. 36, 49–50).
- Estimation: HETOP pools count vectors with fewer than 20 students (p. 35). A "small" flag
  marks cells with fewer than 100 test scores.

### How to download

- **edopportunity.org** (`/trends/data/downloads/`, reached from `/trends/data/`) asks for an
  email address and acceptance of the data use agreement, then links to the files.
- The files are hosted in the **Stanford Digital Repository**, not Harvard Dataverse. Each
  file has a direct URL `https://stacks.stanford.edu/file/np279jm6134/<file name>`, and the
  persistent identifiers are the PURL and the DataCite DOI `10.25740/np279jm6134`. A HEAD
  request on a data file returned 200 with no login. The PURL landing page shows the same
  data use agreement. Machine-readable file lists are at
  `https://purl.stanford.edu/np279jm6134.xml`.
- **No Harvard Dataverse deposit or Dataverse API** was found for any SEDA release.
- **Data use agreement** (documentation p. 6): no commercial use, no re-identification,
  and *"You agree not to publish the data files, in full or in part, without explicit
  permission of the Educational Opportunity Project at Stanford."* This matters for any
  OSF deposit of SEDA extracts.

### Points for the author

1. SEDA covers **grades 3–8 only**. The design's outcome is secondary (high school)
   achievement gaps, so SEDA cannot measure that outcome directly.
2. End years 2020 and 2021 are absent. The registration end year is 2021.
3. The 2022–2025 years come from public suppressed data with different cleaning. That is a
   source change inside the panel, between end years 2019 and 2022.

## 2. ED Data Library, state-level (SEA) achievement files, 2021-22 and 2022-23

Listing read 2026-09-15 at `https://eddataexpress.ed.gov/download/data-library`
(filters: school year, file spec 175 = math performance, 178 = RLA performance).

| School year | Subject | File | FS / DG | Records | Zip size | As of |
|---|---|---|---|---|---|---|
| 2021-22 | Math | `SY2122_FS175_DG583_SEA_data_files.zip` (`.../data_download/EID_12959/`) | 175 / 583 | 6,944 | 76.42 KB | 05/24/2023 |
| 2021-22 | RLA | `SY2122_FS178_DG584_SEA_data_files.zip` (`.../data_download/EID_12960/`) | 178 / 584 | 7,088 | 77.08 KB | 05/24/2023 |
| 2022-23 | Math | **none** | | | | |
| 2022-23 | RLA | **none** | | | | |

- **2022-23 has no assessment file at any level.** The Data Library lists 7 files for
  2022-23 in total: homeless, McKinney-Vento, English learners, and the SEA
  graduation-rate file `FS150/151 DG695/696`. None is FS175, 178, 185 or 188. 2023-24 has none
  either. The Data Download Tool (`/download/data-builder/data-download-tool`) would not
  render its filter panel, and its own notice says so, so it could not be checked for
  2022-23 assessment rows.
- Also in 2021-22: SEA participation files `SY2122_FS185_DG588_SEA_data_files.zip` (math,
  7,090 records, 72.31 KB, EID_12963) and `SY2122_FS188_DG589_SEA_data_files.zip` (RLA,
  7,225 records, 75.62 KB, EID_12965). The LEA level has RLA only
  (`SY2122_FS178_DG584_LEA_data_files.zip`, 1,329,631 records, 17.54 MB), which matches CLAUDE.md.
  The page warns that the data library "has stopped working temporarily for many SY2122
  school files".
- **Subgroup rows: yes, by inference.** The files were not opened. The Data Library layout
  is long, with `Subgroup` and `Characteristics` columns, as in the SY1819 files described in
  `docs/data_acquisition.md` 5.1. 6,944 math records over about 52 SEAs is about 134 rows per
  state. That fits about 8 grade values (3–8, HS, all) times about 17 subgroup categories.
  An all-students-only file would have roughly 400 rows. The SY2020-21 SEA files, 7,178 and
  6,892 records, are the same size. Confirming the exact subgroup list needs one of these
  files to be opened, which this task did not do.
- A state-level file cannot form a within-district gap (the same limit noted for graduation
  in CLAUDE.md).

## 3. DIDmultiplegtDYN on R 4.6.1

- **Version 2.4.0** (CRAN, published 2026-06-30). The Windows binary for R 4.6 installs and
  loads on R 4.6.1 (ucrt). It pulled in about 80 dependencies, including `fixest` 0.14.2
  (the renv version) and `data.table`, `dplyr`, `ggplot2` and `car`.
- **polars is required at run time.** CRAN lists `polars` under Suggests, but the estimator
  stops with *"The 'polars' package is required but not installed"* without it. polars is
  not on CRAN; the only build installed was `polars 1.9000.9000.9000` from
  `rpolars.r-universe.dev`, a development-numbered build. It also has to be **attached**
  (`library(polars)`); otherwise the call fails with `object 'pl' not found`. Adding it to
  `renv.lock` would need the r-universe repository recorded in the lockfile.
- A long scratch library path failed to install `RcppArmadillo` because of the Windows
  260-character path limit. A short library path installed cleanly.

Smoke tests on simulated data: 300 units in 30 "states", 10 periods, staggered
switches, one third of switchers reverting to baseline.

| Test | Result |
|---|---|
| Binary→continuous-dose switch from a zero baseline, `effects = 3, placebo = 2, cluster = "state"` | runs; event-study effects, placebos and joint placebo test printed |
| Continuous baseline treatment, `continuous = 1`, `cluster = "state"`, analytical SEs, non-absorbing | **runs**: Effect_1..3, average total effect, Placebo_1..2 and the "joint nullity of the placebos" p-value. The package warns that analytical SEs "can be liberal" with `continuous` and recommends `bootstrap` |
| Continuous baseline without `continuous` | stops by design: "Design Restriction 1 ... not satisfied" and suggests `continuous` |
| `continuous = 1` with a zero baseline everywhere | fails in `feols` (no variation in baseline treatment), a property of the test data |
| `continuous = 1` + `bootstrap = 50` + `cluster = "state"` | **crashed twice at about bootstrap replication 10**: `memory allocation of 116160 bytes failed` inside polars' Rust code, R exit code 0xC0000409, with 23 GB RAM free. Not resolved |

Support summary:
- **Continuous treatment:** yes (`continuous = <polynomial order>` for the baseline treatment).
- **Non-absorbing:** yes. Treatment can switch on and off (`switchers = "in"/"out"`
  available). Effects are indexed from each unit's first change in treatment.
- **State clusters:** yes (`cluster = "state"`), analytical SEs. The package-recommended
  bootstrap combined with `continuous` crashed on this machine with the r-universe polars
  build.
- **Placebo pre-trend tests:** yes (`placebo = k`, with a joint test of the placebos).
- `did_multiplegt_dyn()` arguments include `effects, placebo, controls, trends_nonparam,
  trends_lin, continuous, weight, cluster, by, predict_het, same_switchers, switchers,
  only_never_switchers, bootstrap, normalized, effects_equal, less_conservative_se`.

The design's reference estimators (CLAUDE.md rule 6) do not include this package. Using it
would be a design decision for the author.
