edfacts_exact <- function(x) {
  x <- trimws(as.character(x))
  out <- suppressWarnings(as.numeric(x))
  out[!grepl("^[0-9]+(\\.[0-9]+)?$", x)] <- NA_real_
  out
}

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

edfacts_suppressed <- function(x) {
  x <- trimws(as.character(x))
  !is.na(x) & nzchar(x) & !grepl("^[0-9]+(\\.[0-9]+)?$", x)
}
