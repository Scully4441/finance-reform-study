source("R/functions/stage.R")
stage <- as.integer(readLines("data/stage.txt", n = 1, warn = FALSE))
if (!stage %in% c(1L, 2L)) stop("data/stage.txt must be 1 or 2")

options(HTTPUserAgent = "finance-reform-study (R download.file; academic research)",
        timeout = max(1800, getOption("timeout")))

man <- read.csv("data/manifest/download_manifest.csv", stringsAsFactors = FALSE,
                colClasses = "character", na.strings = character(0))
man$sy_end <- as.integer(man$sy_end)
blank <- function(x) is.na(x) | !nzchar(trimws(x))
allowed <- stage_allows(man$dataset, man$sy_end, stage)

for (i in seq_len(nrow(man))) {
  label <- paste(man$dataset[i], man$sy_end[i])
  if (!allowed[i]) {
    message("stage 1 gate: skipping ", label); next
  }
  if (blank(man$filename[i])) { message("nothing archived yet: ", label); next }
  dest <- file.path("data", "raw", man$filename[i])
  if (!file.exists(dest)) {
    if (blank(man$url[i])) { message("not in data/raw and no url: ", label); next }
    dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
    message("downloading ", label)
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
