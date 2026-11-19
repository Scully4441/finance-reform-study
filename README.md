# Finance reform study

Analysis code for a dissertation study of state school finance reforms and
within-state achievement gaps: a staggered difference-in-differences design on
the federal EDFacts high school files, high school report-card years
2022-2025, SEDA grades 3-8 outcomes, graduation-rate gaps, and a
continuous-treatment estimator. The code is released under the MIT license
(`LICENSE`).

## Layout

- `R/` numbered step scripts in run order (00-13); shared functions in `R/functions/`
- `data/manifest/` download manifest (see its README)
- `data/reference/` reference tables; the event tables are written by step 1
- `data/stage.txt` download stage gate (`1` until registration, then `2`)
- `data/raw/`, `data/derived/`, `outputs/` are not committed
- `tests/` test suite (`Rscript tests/run_tests.R`)

## Running

The container pins R 4.6.1 and restores the packages in `renv.lock`. It holds
the code and the lockfile only; the repository folder, with the data, is
mounted at run time.

```
docker build -t finance-reform-study .
docker run --rm -v "${PWD}:/study" finance-reform-study Rscript tests/run_tests.R
docker run --rm -v "${PWD}:/study" finance-reform-study
```

The last command runs `R/13_run_all.R`, which needs `data/stage.txt` set to
`2` and the files in `data/raw/` (fetched and verified by `R/02_download.R`).
Without Docker, run the same scripts with `Rscript` from the repository folder
after `renv::restore()`.

## Data availability

All inputs are public except SEDA. The SEDA files are used under the SEDA
data use agreement and are not included or redistributed; a reader must
accept the agreement at edopportunity.org and download them from the
addresses in the manifest. The reform event files and the blinding seed are
held outside the repository.
