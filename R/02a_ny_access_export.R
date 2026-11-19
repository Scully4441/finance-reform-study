source("R/functions/stage.R")
stage <- read_stage()
if (!identical(stage, 2L)) stop("R/02a_ny_access_export.R reads a report-card outcome file, which needs data/stage.txt = 2.")
for (tool in c("mdb-export", "mdb-tables", "unzip"))
  if (!nzchar(Sys.which(tool))) stop(tool, " not found: run this script in the project container with mdbtools and unzip installed.")

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
