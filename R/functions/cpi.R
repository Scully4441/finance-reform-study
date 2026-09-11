# CPI-U deflator (design document, Section 7, "Dose scaling").
# monthly: data.frame with columns year, month, value for BLS series
# CUUR0000SA0 (CPI-U, U.S. city average, all items, not seasonally adjusted).
# A school year ending in year Y runs July of Y-1 through June of Y.

cpi_school_year <- function(monthly) {
  stopifnot(all(c("year", "month", "value") %in% names(monthly)))
  sy_end <- ifelse(monthly$month >= 7, monthly$year + 1, monthly$year)
  agg <- aggregate(list(cpi = monthly$value), list(sy_end = sy_end), mean)
  n <- aggregate(list(n = monthly$value), list(sy_end = sy_end), length)
  agg$complete <- n$n[match(agg$sy_end, n$sy_end)] == 12
  agg
}

# Express nominal dollars from school year sy_end in dollars of base_sy_end.
deflate_to_base <- function(nominal, sy_end, cpi_table, base_sy_end) {
  base <- cpi_table$cpi[cpi_table$sy_end == base_sy_end]
  stopifnot(length(base) == 1L)
  cpi <- cpi_table$cpi[match(sy_end, cpi_table$sy_end)]
  if (any(is.na(cpi))) stop("CPI missing for some school years")
  nominal * base / cpi
}
