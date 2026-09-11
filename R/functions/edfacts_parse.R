# EDFacts value parsing (design document, Section 5, "Suppression").
# EDFacts reports a cell as an exact number or, when counts are small, as a
# range or symbol ("GE50", "LT5", "20-29", "PS"). Counts are used only when
# exact. Percent proficient may enter as a range midpoint (author decision
# 2026-09-11, data acquisition 4.1): edfacts_range() gives its bounds.

edfacts_exact <- function(x) {
  x <- trimws(as.character(x))
  out <- suppressWarnings(as.numeric(x))
  out[!grepl("^[0-9]+(\\.[0-9]+)?$", x)] <- NA_real_
  out
}

# A reported percentage as a range, from its printed endpoints: an exact value
# v is [v, v]; "a-b" is [a, b]; "GEnn"/"GTnn" is [nn, 100]; "LEnn"/"LTnn" is
# [0, nn]. width = hi - lo in percentage points (0 for an exact value) and
# mid = (lo + hi) / 2, so "20-29" has width 9 and midpoint 24.5 and "GE95"
# width 5 and midpoint 97.5. Suppressed or blank values ("PS", "N/A", ".", "")
# give NA throughout.
edfacts_range <- function(x) {
  x <- toupper(trimws(as.character(x)))
  num <- "[0-9]+(\\.[0-9]+)?"
  lo <- hi <- rep(NA_real_, length(x))
  ex <- grepl(paste0("^", num, "$"), x)
  lo[ex] <- hi[ex] <- as.numeric(x[ex])
  rg <- grepl(paste0("^", num, "-", num, "$"), x)
  lo[rg] <- as.numeric(sub("-.*$", "", x[rg]))
  hi[rg] <- as.numeric(sub("^.*-", "", x[rg]))
  ge <- grepl(paste0("^G[ET]", num, "$"), x)
  lo[ge] <- as.numeric(substring(x[ge], 3))
  hi[ge] <- 100
  le <- grepl(paste0("^L[ET]", num, "$"), x)
  lo[le] <- 0
  hi[le] <- as.numeric(substring(x[le], 3))
  bad <- !is.na(lo) & (lo > hi | hi > 100)
  if (any(bad)) stop("percent range reversed or above 100: ", paste(unique(x[bad]), collapse = ", "))
  data.frame(lo = lo, hi = hi, width = hi - lo, mid = (lo + hi) / 2)
}

# TRUE when a cell was reported as anything other than an exact number
# (used for the sample-inclusion indicator in the selection check, Section 9).
edfacts_suppressed <- function(x) {
  x <- trimws(as.character(x))
  !is.na(x) & nzchar(x) & !grepl("^[0-9]+(\\.[0-9]+)?$", x)
}
