# EDFacts value parsing (design document, Section 5, "Suppression").
# EDFacts reports a cell as an exact number or, when counts are small, as a
# range or symbol ("GE50", "LT5", "20-29", "PS"). The design uses exact
# values only. Anything that is not a plain number becomes NA.

edfacts_exact <- function(x) {
  x <- trimws(as.character(x))
  out <- suppressWarnings(as.numeric(x))
  out[!grepl("^[0-9]+(\\.[0-9]+)?$", x)] <- NA_real_
  out
}

# TRUE when a cell was reported as anything other than an exact number
# (used for the sample-inclusion indicator in the selection check, Section 9).
edfacts_suppressed <- function(x) {
  x <- trimws(as.character(x))
  !is.na(x) & nzchar(x) & !grepl("^[0-9]+(\\.[0-9]+)?$", x)
}
