# CPI-U deflator (design document, Section 7, "Dose scaling").
# monthly: data.frame with columns year, month, value for BLS series
# CUUR0000SA0 (CPI-U, U.S. city average, all items, not seasonally adjusted).
# A school year ending in year Y runs July of Y-1 through June of Y.

# Missing months are filled first (cpi_fill_gaps); `filled` counts them per year.
cpi_school_year <- function(monthly) {
  stopifnot(all(c("year", "month", "value") %in% names(monthly)))
  monthly <- cpi_fill_gaps(monthly)
  sy_end <- ifelse(monthly$month >= 7, monthly$year + 1, monthly$year)
  agg <- aggregate(list(cpi = monthly$value), list(sy_end = sy_end), mean)
  n <- aggregate(list(n = monthly$value), list(sy_end = sy_end), length)
  f <- aggregate(list(f = monthly$filled), list(sy_end = sy_end), sum)
  agg$complete <- n$n[match(agg$sy_end, n$sy_end)] == 12
  agg$filled <- f$f[match(agg$sy_end, f$sy_end)]
  agg
}

# Design v17, Section 7: a month missing from the published series is filled
# with the mean of the two adjacent months. Only single-month gaps inside the
# published range are filled; months after the last published value are not
# yet released and are left out. A run of two or more missing months stops
# with an error because the rule does not cover it.
cpi_fill_gaps <- function(monthly) {
  stopifnot(all(c("year", "month", "value") %in% names(monthly)))
  monthly <- monthly[!is.na(monthly$value), c("year", "month", "value")]
  idx <- monthly$year * 12 + monthly$month - 1
  if (anyDuplicated(idx)) stop("duplicate CPI months")
  gap <- setdiff(seq(min(idx), max(idx)), idx)
  if (any(diff(gap) == 1)) stop("two or more consecutive CPI months missing")
  fill <- data.frame(year = gap %/% 12, month = gap %% 12 + 1,
                     value = (monthly$value[match(gap - 1, idx)] +
                              monthly$value[match(gap + 1, idx)]) / 2)
  monthly$filled <- rep(FALSE, nrow(monthly))
  fill$filled <- rep(TRUE, nrow(fill))
  out <- rbind(monthly, fill)
  out[order(out$year, out$month), , drop = FALSE]
}

# Read the BLS data-viewer .xlsx export of CUUR0000SA0 (one row per year,
# columns Jan..Dec, HALF1, HALF2) into the monthly format above. Base R only:
# an .xlsx is a zip of XML parts. Months BLS left blank (October 2025, lapse in
# appropriations) are dropped here and filled by cpi_fill_gaps().
cpi_from_bls_xlsx <- function(path) {
  td <- tempfile("xlsx"); on.exit(unlink(td, recursive = TRUE))
  utils::unzip(path, files = c("xl/sharedStrings.xml", "xl/worksheets/sheet1.xml"), exdir = td)
  rd <- function(f) paste(readLines(file.path(td, f), warn = FALSE, encoding = "UTF-8"), collapse = "")
  ss <- regmatches(rd("xl/sharedStrings.xml"),
                   gregexpr("<si>.*?</si>", rd("xl/sharedStrings.xml"), perl = TRUE))[[1]]
  strings <- gsub("<[^>]+>", "", ss)
  if (!"CUUR0000SA0" %in% strings || !"Not Seasonally Adjusted" %in% strings) {
    stop("not the BLS CUUR0000SA0 (not seasonally adjusted) export: ", path)
  }
  sh <- rd("xl/worksheets/sheet1.xml")
  cells <- regmatches(sh, gregexpr('<c r="[A-Z]+[0-9]+"[^>]*>(<v>[^<]*</v>)?</c>', sh, perl = TRUE))[[1]]
  col <- sub('^<c r="([A-Z]+)[0-9]+".*', "\\1", cells)
  row <- as.integer(sub('^<c r="[A-Z]+([0-9]+)".*', "\\1", cells))
  val <- ifelse(grepl("<v>", cells), sub(".*<v>([^<]*)</v>.*", "\\1", cells), NA_character_)
  is_str <- grepl(' t="s"', cells)
  val[is_str] <- strings[as.integer(val[is_str]) + 1L]
  hdr_row <- row[col == "A" & is_str & val == "Year"]
  stopifnot(length(hdr_row) == 1L)
  hdr <- setNames(val[row == hdr_row], col[row == hdr_row])
  month_col <- setNames(names(hdr)[match(month.abb, hdr)], month.abb)
  stopifnot(!anyNA(month_col))
  num <- !is_str & row > hdr_row & !is.na(val)
  years <- setNames(as.integer(as.numeric(val[num & col == "A"])), row[num & col == "A"])
  keep <- num & col %in% month_col & as.character(row) %in% names(years)
  out <- data.frame(series_id = "CUUR0000SA0",
                    year = unname(years[as.character(row[keep])]),
                    month = match(col[keep], month_col),
                    value = as.numeric(val[keep]))
  out[order(out$year, out$month), , drop = FALSE]
}

# Express nominal dollars from school year sy_end in dollars of base_sy_end.
deflate_to_base <- function(nominal, sy_end, cpi_table, base_sy_end) {
  base <- cpi_table$cpi[cpi_table$sy_end == base_sy_end]
  stopifnot(length(base) == 1L)
  cpi <- cpi_table$cpi[match(sy_end, cpi_table$sy_end)]
  if (any(is.na(cpi))) stop("CPI missing for some school years")
  nominal * base / cpi
}
