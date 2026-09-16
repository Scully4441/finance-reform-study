# Step 2. Download the files listed in data/manifest/download_manifest.csv,
# record a SHA-256 checksum and the download time, and verify checksums on
# later runs (design document, Section 4).
#
# Stage gate (design document, Sections 4, 10, 11): while data/stage.txt is 1,
# EDFacts outcome files (dataset names starting with "edfacts_") for school
# years ending after 2013 are skipped. Do not bypass this.

stage <- as.integer(readLines("data/stage.txt", n = 1, warn = FALSE))
if (!stage %in% c(1L, 2L)) stop("data/stage.txt must be 1 or 2")

# ed.gov answers 403 to R's default user agent, so identify the client plainly.
# The larger files take longer than R's 60-second default timeout.
options(HTTPUserAgent = "finance-reform-study (R download.file; academic research)",
        timeout = max(1800, getOption("timeout")))

man <- read.csv("data/manifest/download_manifest.csv", stringsAsFactors = FALSE,
                colClasses = "character", na.strings = character(0))
man$sy_end <- as.integer(man$sy_end)
blank <- function(x) is.na(x) | !nzchar(trimws(x))
is_outcome <- grepl("^edfacts_", man$dataset)

for (i in seq_len(nrow(man))) {
  label <- paste(man$dataset[i], man$sy_end[i])
  if (stage == 1L && is_outcome[i] && !is.na(man$sy_end[i]) && man$sy_end[i] > 2013L) {
    message("stage 1 gate: skipping outcome file ", label); next
  }
  # A blank url is not a reason to skip the row: the Run 2 report-card rows are
  # exported by hand from an interactive tool and have no url to fetch from, but
  # the file is in data/raw all the same and its checksum is verified here like
  # any other. A blank filename means there is nothing on disk yet.
  if (blank(man$filename[i])) { message("nothing archived yet: ", label); next }
  dest <- file.path("data", "raw", man$filename[i])
  if (!file.exists(dest)) {
    if (blank(man$url[i])) { message("not in data/raw and no url: ", label); next }
    dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
    message("downloading ", label)
    # Download under a temporary name so a failed transfer never leaves a
    # partial file that a later run would checksum as the archived version.
    part <- paste0(dest, ".part")
    utils::download.file(man$url[i], part, mode = "wb", quiet = TRUE)
    if (!file.rename(part, dest)) stop("could not move ", part, " to ", dest)
  }
  h <- digest::digest(file = dest, algo = "sha256")
  if (!blank(man$sha256[i]) && man$sha256[i] != h) {
    stop("Checksum mismatch for ", dest, ". The file changed since it was archived.")
  }
  if (blank(man$sha256[i])) {
    man$sha256[i] <- h
    man$downloaded_utc[i] <- format(Sys.time(), tz = "UTC", "%Y-%m-%dT%H:%M:%SZ")
  }
}
write.csv(man, "data/manifest/download_manifest.csv", row.names = FALSE, na = "")
message("manifest updated")
