# Step 2a (Run 2). Export the New York School Report Card Access table read by step 12 to CSV
# (docs/design_extension.md, Section 4; docs/deviations_run2.md, 2026-09-16).
#
# New York publishes each year's report-card data only as an Access database inside a zip
# (data/raw/hs_reportcards/NY/SRC<yyyy>.zip). R has no Access reader that works in the Linux
# container, and this machine has only the 32-bit Jet ODBC driver, which 64-bit R cannot load,
# so the table is exported with mdbtools inside the project image. The CSV copies are archived
# beside the zips, with their own manifest rows and checksums (hs_reportcard_ny_src_csv).
#
# Run from the repository folder on the host (Git Bash; MSYS_NO_PATHCONV keeps the paths):
#   MSYS_NO_PATHCONV=1 docker run --rm -v "$PWD:/study" -w /study finance-reform-study:latest \
#     bash -c "apt-get update -qq && apt-get install -y -qq --no-install-recommends mdbtools unzip \
#              && Rscript R/02a_ny_access_export.R"
# Then Rscript R/02_download.R records and verifies the checksums of the new manifest rows.
#
# Output: data/raw/hs_reportcards/NY/SRC<yyyy>_annual_regents_exams.csv, the whole table
# [Annual Regents Exams] of SRC<yyyy>'s .mdb member (it carries the prior year's rows too),
# as mdb-export writes it: header row, comma-separated, text quoted.

stage2 <- as.integer(readLines("data/stage_run2.txt", n = 1, warn = FALSE))
if (!identical(stage2, 2L)) stop("R/02a_ny_access_export.R reads a Run 2 outcome file, which needs data/stage_run2.txt = 2.")
for (tool in c("mdb-export", "mdb-tables", "unzip"))
  if (!nzchar(Sys.which(tool))) stop(tool, " not found: run this script in the container (see the header).")

NY_TABLE <- "Annual Regents Exams"
ny_dir <- "data/raw/hs_reportcards/NY"

for (y in 2022:2025) {
  zip <- file.path(ny_dir, sprintf("SRC%d.zip", y))
  members <- utils::unzip(zip, list = TRUE)$Name
  mdb <- grep("\\.mdb$", members, value = TRUE)
  if (length(mdb) != 1L) stop(zip, ": expected one .mdb member, found ", length(mdb))
  td <- tempfile("ny"); dir.create(td)
  status <- system2("unzip", c("-q", "-o", shQuote(zip), shQuote(mdb), "-d", shQuote(td)))
  if (status != 0L) stop("unzip failed for ", zip)
  db <- file.path(td, mdb)
  tables <- system2("mdb-tables", c("-1", shQuote(db)), stdout = TRUE)
  if (!NY_TABLE %in% tables) stop(mdb, ": no table [", NY_TABLE, "]; tables: ", paste(tables, collapse = "; "))
  out <- file.path(ny_dir, sprintf("SRC%d_annual_regents_exams.csv", y))
  status <- system2("mdb-export", c(shQuote(db), shQuote(NY_TABLE)), stdout = out)
  if (status != 0L) stop("mdb-export failed for ", mdb)
  unlink(td, recursive = TRUE)
  message(sprintf("%s: %s rows -> %s", mdb, length(readLines(out)) - 1L, out))
}
