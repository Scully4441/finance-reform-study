# Finance reform study

Analysis code for a dissertation study of state school finance reforms and
within-state achievement gaps: a staggered difference-in-differences design on
the federal EDFacts high school files, high school report-card years
2022-2025, SEDA grades 3-8 outcomes, graduation-rate gaps, and a
continuous-treatment estimator. The code is released under the MIT license
(`LICENSE`).

The pre-analysis plan is registered on OSF: https://osf.io/583x7

## Layout

- `R/` numbered step scripts in run order (00-13); shared functions in `R/functions/`
- `data/manifest/` download manifest (see its README)
- `data/reference/` reference tables; the event tables are written by step 1
- `data/stage.txt` download stage gate (`1` until registration, then `2`)
- `tests/` testthat suite (`Rscript tests/run_tests.R`, which exits non-zero on a failure)
- `docs/` design document, decision log and deviations log

## Data folders

Downloaded files go in `data/raw/` and derived files, model objects and
randomization draws in `data/derived/`, inside the working copy. Both folders,
like `outputs/`, are excluded from version control and are never committed.

## System requirements

R 4.6.1 with the packages pinned in `renv.lock` (`renv::restore()`, run by step
0). Building HonestDiD's solver dependency from source needs the Rust toolchain
1.85.0; the container installs it. The New York Access exports
(`R/02a_ny_access_export.R`) need mdbtools 1.0.0, also installed in the container.

## Running

The container restores the lockfile and holds the code only; the working copy,
with its data folders, is mounted at run time.

```
docker build -t finance-reform-study .
docker run --rm -v "${PWD}:/study" finance-reform-study Rscript tests/run_tests.R
docker run --rm -v "${PWD}:/study" finance-reform-study
```

The last command runs `R/13_run_all.R`, which needs `data/stage.txt` set to
`2` and the files in `data/raw/` (fetched and verified by `R/02_download.R`).
At stage 1, steps 3-5 run on end years 2010-2013 and step 8 runs the power
simulation. Without Docker, run the same scripts with `Rscript` from the
repository folder.

## Data availability

All inputs are public except SEDA. The SEDA files are used under the SEDA
data use agreement and are not included or redistributed; a reader must
accept the agreement at edopportunity.org and download them from the
addresses in the manifest. The reform event files and the blinding seed are
held outside the repository.
