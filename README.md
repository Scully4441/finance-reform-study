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