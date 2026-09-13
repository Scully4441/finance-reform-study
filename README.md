# Finance reform study

Dissertation pipeline for the design in `docs/design.md`. Code is released
under the MIT license (see `LICENSE`).

Folder layout

- `R/` numbered scripts in run order; shared functions in `R/functions/`
- `data/manifest/` download manifest with checksums (tracked)
- `data/raw/` downloaded federal files (not tracked)
- `data/reference/` event tables (permuted until unblinding), test-replacement table, CEP table, CPI
- `docs/` design (`design.md`), data specification (`data_acquisition.md`), deviations log
- `outputs/` results and logs (not tracked, except package versions)
- `tests/` base-R checks

The folder `../finance-reform-study-private/` sits beside this repository and
holds the real reform tables and the permutation seed. It is never committed
and never opened inside a Claude Code session.

Two files gate the run: `data/stage.txt` (download stage) and
`data/reference/blinding_status.txt` (PERMUTED or REAL). See `CLAUDE.md`.
Registration: https://doi.org/10.17605/OSF.IO/JNM6D 09/11/2026

## How to reproduce

The container pins R 4.6.1 and restores the packages in `renv.lock`. The image
holds code and the lockfile only; `data/raw`, `data/derived` and `outputs` are
not built into it, and the repository folder is mounted as `/study` at run time.

1. Place the OSF-deposited files under `data/raw/`, or run `Rscript R/02_download.R`.
2. From the repository folder, build the image:

   ```
   docker build -t finance-reform-study .
   ```

3. Run the pipeline with the repository mounted as `/study`
   (PowerShell; in a POSIX shell use `"$(pwd)":/study`):

   ```
   docker run --rm -v "${PWD}:/study" finance-reform-study
   ```

   The tests run the same way:

   ```
   docker run --rm -v "${PWD}:/study" finance-reform-study Rscript tests/run_tests.R
   ```

Packages: `fwildclusterboot`, `wildrwolf`, `summclust` and `testthat` appear in
`outputs/package_versions.csv` because they were installed, but no script uses
them, so they are not in `renv.lock`: the wild cluster bootstrap and Romano–Wolf
are computed on the did influence function.