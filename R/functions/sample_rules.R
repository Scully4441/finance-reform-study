# Sample construction rules (design document, Section 5; data acquisition 2.1-2.6, 4).
# Readers for the stage-1 raw files and the rule functions used by R/03_sample.R.
# Author decisions 2026-09-11 applied here (recorded in docs/data_acquisition.md 4.1):
#   participation passes only when the reported value's lower bound is >= 95;
#   poverty quintiles are fixed per state among high school districts;
#   stability = operational (BOUND not 2, 6, 7) every window year and never BOUND 5.
# Later the same day: percent proficient may enter as the midpoint of a range no
# wider than 10 points (replacing exact-only), BOUND 8 counts as a change, and
# participation is tested at the exact value or band midpoint (replacing the lower bound).

# Two-digit state FIPS codes for the 50 states and DC (the study universe).
STATE_FIPS <- c(AL = "01", AK = "02", AZ = "04", AR = "05", CA = "06", CO = "08", CT = "09", DE = "10",
                DC = "11", FL = "12", GA = "13", HI = "15", ID = "16", IL = "17", IN = "18", IA = "19",
                KS = "20", KY = "21", LA = "22", ME = "23", MD = "24", MA = "25", MI = "26", MN = "27",
                MS = "28", MO = "29", MT = "30", NE = "31", NV = "32", NH = "33", NJ = "34", NM = "35",
                NY = "36", NC = "37", ND = "38", OH = "39", OK = "40", OR = "41", PA = "42", RI = "44",
                SC = "45", SD = "46", TN = "47", TX = "48", UT = "49", VT = "50", VA = "51", WA = "53",
                WV = "54", WI = "55", WY = "56")

fips_to_state <- function(fips) {
  out <- names(STATE_FIPS)[match(fips, STATE_FIPS)]
  out[is.na(out)] <- NA_character_
  out
}

# EDFacts subgroups carried into the sample file, with short column suffixes.
SUBGROUPS <- c(ALL = "all", MWH = "wh", MBL = "bl", MHI = "hi", ECD = "ecd")
SUBJECTS  <- c(math = "MTH", rla = "RLA")

# School-year tag used in EDFacts column names: end year 2010 -> "0910".
edfacts_year_tag <- function(sy_end) sprintf("%02d%02d", (sy_end - 1L) %% 100L, sy_end %% 100L)

# ---- readers -------------------------------------------------------------------

# CCD LEA universe flat file (tab-delimited). Quoted names can hold a tab, so the
# file is read with standard quoting, and the row count is checked against the
# number of physical lines so that no row is silently dropped or split.
# extra: further CCD fields to return as reported (character), named in lower case,
# e.g. extra = "MEMBER" for the gap (a) weights in R/04_outcomes.R.
read_ccd_lea <- function(path, sy_end, extra = character()) {
  n_lines <- length(readLines(path, warn = FALSE)) - 1L
  d <- utils::read.delim(path, colClasses = "character", quote = "\"",
                         na.strings = character(), comment.char = "")
  if (!"TYPE" %in% names(d))                        # 2009-10 suffixes names with the year: TYPE09
    names(d) <- sub(sprintf("%02d$", (sy_end - 1L) %% 100L), "", names(d))
  if (nrow(d) != n_lines) stop(basename(path), ": read ", nrow(d), " rows from ", n_lines, " data lines")
  need <- c("LEAID", "FIPST", "TYPE", "BOUND", "GSHI", extra)
  miss <- setdiff(need, names(d))
  if (length(miss)) stop(basename(path), " lacks columns: ", paste(miss, collapse = ", "))
  d <- d[need]
  d$LEAID <- trimws(d$LEAID)
  if (!all(grepl("^[0-9]{7}$", d$LEAID))) stop(basename(path), ": LEAID not 7 digits")
  if (anyDuplicated(d$LEAID)) stop(basename(path), ": duplicate LEAID")
  if (!all(d$TYPE %in% as.character(1:8)) || !all(d$BOUND %in% as.character(1:8)))
    stop(basename(path), ": TYPE or BOUND outside 1-8")
  out <- data.frame(leaid = d$LEAID, fipst = substr(d$LEAID, 1, 2), sy_end = as.integer(sy_end),
                    agency_type = as.integer(d$TYPE), ccd_bound = as.integer(d$BOUND),
                    gshi = trimws(d$GSHI), stringsAsFactors = FALSE)
  for (v in extra) out[[tolower(v)]] <- trimws(d[[v]])
  out
}

# EDFacts LEA file, high school band only (grade "HS", never "00").
# kind = "achievement": returns n_<sg> (raw valid-test count) and p_<sg> (raw percent proficient).
# kind = "participation": returns part_<sg> (raw percent participating).
# Values are returned as reported (character); callers parse them.
read_edfacts_hs <- function(path, subject, sy_end, kind = c("achievement", "participation")) {
  kind <- match.arg(kind)
  code <- SUBJECTS[[subject]]
  d <- utils::read.csv(path, colClasses = "character", na.strings = character(), check.names = FALSE)
  up <- toupper(names(d))
  tag <- edfacts_year_tag(sy_end)
  col <- function(sg, field) {
    k <- which(up == paste0(sg, "_", code, "HS", field, "_", tag))
    if (length(k) != 1L) stop(basename(path), ": expected one column for ", sg, " ", field)
    d[[k]]
  }
  leaid <- trimws(d[[which(up == "LEAID")]])
  if (!all(grepl("^[0-9]{7}$", leaid))) stop(basename(path), ": LEAID not 7 digits")
  if (anyDuplicated(leaid)) stop(basename(path), ": duplicate LEAID")
  out <- data.frame(leaid = leaid, stringsAsFactors = FALSE)
  for (sg in names(SUBGROUPS)) {
    s <- SUBGROUPS[[sg]]
    if (kind == "achievement") {
      out[[paste0("n_", s)]] <- col(sg, "NUMVALID")
      out[[paste0("p_", s)]] <- col(sg, "PCTPROF")
    } else {
      out[[paste0("part_", s)]] <- col(sg, "PCTPART")
    }
  }
  out
}

# SAIPE school district file (fixed-width text). Fields are taken by pattern
# because column positions differ between releases.
read_saipe <- function(path) {
  x <- iconv(readLines(path, warn = FALSE), from = "latin1", to = "UTF-8")   # names carry Latin-1 accents
  x <- x[nzchar(trimws(x))]
  re <- "^([0-9]{2}) ([0-9]{5}) (.*[^ ]) +([0-9]+) +([0-9]+) +([0-9]+) +([^ ]+) +([^ ]+) *$"
  bad <- !grepl(re, x)
  if (any(bad)) stop(basename(path), ": ", sum(bad), " lines do not match the SAIPE layout")
  f <- function(i) sub(re, paste0("\\", i), x)
  d <- data.frame(leaid = paste0(f(1), f(2)), name = f(3), pop_total = as.numeric(f(4)),
                  pop_5_17 = as.numeric(f(5)), pov_5_17 = as.numeric(f(6)), stringsAsFactors = FALSE)
  if (anyDuplicated(d$leaid)) stop(basename(path), ": duplicate district")
  d$pov_rate <- ifelse(d$pop_5_17 > 0, d$pov_5_17 / d$pop_5_17, NA_real_)
  d
}

# ---- rules ---------------------------------------------------------------------

# Widest percent-proficient range, in percentage points, that each sample admits
# (author decision 2026-09-11, replacing the exact-only rule): the primary sample
# and two robustness samples, ranges of 5 points or less and exact values only.
MAX_WIDTH <- c(primary = 10, r5 = 5, exact = 0)

# Rule 3 (suppression). The valid-test count must be exact and at least 30. The
# percent proficient enters as the exact value or, when reported as a range no
# wider than max_width points, at the range midpoint (edfacts_range()).
# One status per district-year-subject-subgroup cell:
#   not_reported  no exact valid-test count in the file
#   below_30      exact count under 30
#   suppressed    count of 30 or more, percent proficient not reported (PS, N/A, blank)
#   wide_range    count of 30 or more, percent proficient a range wider than max_width
#   usable        count of 30 or more, percent proficient exact or a range of max_width or less
cell_status <- function(n_raw, p_raw, floor = 30, max_width = MAX_WIDTH[["primary"]]) {
  n <- edfacts_exact(n_raw)
  w <- edfacts_range(p_raw)$width
  ifelse(is.na(n), "not_reported",
         ifelse(n < floor, "below_30",
                ifelse(is.na(w), "suppressed",
                       ifelse(w > max_width, "wide_range", "usable"))))
}

# TRUE where a cell enters the named sample: usable under the primary rule and
# a range width within that sample's limit (width 0 = exact value).
cell_in_sample <- function(status, width, sample = names(MAX_WIDTH)) {
  sample <- match.arg(sample)
  status == "usable" & !is.na(width) & width <= MAX_WIDTH[[sample]]
}

# Rule 4 (participation; author decision 2026-09-11, replacing the lower-bound
# reading). The rate tested is the exact value where one is reported and the band
# midpoint where participation is banded, from the printed endpoints as in rule 3
# (edfacts_range()): "GE90" is 95, "90-94" is 92, "GE95" is 97.5, "LT50" is 25.
# Suppressed or blank values ("PS", "n/a", ".", "") give NA (nothing reported).
part_value <- function(x) edfacts_range(x)$mid

# TRUE when that rate is at least 95 percent: GE90 passes, lower bands fail, and
# nothing reported fails. Cells in the exact-only sample report participation as
# an exact value or GE99, so the same test keeps their exact values.
part_pass <- function(x, threshold = 95) {
  v <- part_value(x)
  !is.na(v) & v >= threshold
}

# Rules 1 and 2 at the district level, from the long CCD table (one row per
# listed district-year). Returns one row per district with the first rule failed.
#   rule 1: agency type 1 or 2 in every listed window year
#   rule 2: listed and operational (BOUND not 2, 6, 7) in every window year,
#           and never BOUND 5 (significant boundary change) or 8 (reopened;
#           author decision 2026-09-11) in any window year
BOUND_CHANGE <- c(5L, 8L)
district_rules <- function(lea, window) {
  ids <- sort(unique(lea$leaid))
  sp <- split(lea, factor(lea$leaid, levels = ids))
  res <- vapply(sp, function(g) {
    g <- g[g$sy_end %in% window, ]
    if (any(!g$agency_type %in% 1:2)) return("rule 1: agency type not 1 or 2")
    op <- g$sy_end[!g$ccd_bound %in% c(2L, 6L, 7L)]
    if (!all(window %in% op)) return("rule 2: not operational in every window year")
    if (any(g$ccd_bound %in% BOUND_CHANGE)) return("rule 2: boundary change (BOUND 5 or 8)")
    "pass"
  }, character(1))
  data.frame(leaid = ids, rule12 = unname(res), stringsAsFactors = FALSE)
}

# Poverty quintiles fixed at SAIPE 2009 (Section 6, gap (a); author decision
# 2026-09-11). Within each state, districts are ranked by the 2009 child-poverty
# rate (ties broken by LEAID) and split into five groups of equal count:
# quintile 1 = lowest poverty, 5 = highest. Pass only the districts that form
# the quintiles.
poverty_quintile <- function(state, rate, leaid) {
  stopifnot(length(state) == length(rate), length(rate) == length(leaid), !anyNA(rate))
  q <- integer(length(rate))
  for (s in unique(state)) {
    k <- which(state == s)
    r <- integer(length(k))
    r[order(rate[k], leaid[k])] <- seq_along(k)
    q[k] <- as.integer(ceiling(5 * r / length(k)))
  }
  q
}

# ---- Community Eligibility Provision (data acquisition 2.5) ----------------------

# The CCD records the provision under which each school takes part in the National
# School Lunch Program in NSLPSTATUS, added with the SY2013-14 collection. It is a
# school Characteristics field, not a Lunch Program Eligibility field: ccd_sch_033
# carries only free and reduced-price counts and has no CEP value in any year.
# Three layouts, all read here:
#   end year 2014      combined school universe file sc132a.txt, column NSLPSTATUS,
#                      codes NSLPCEO / NSLPWOPRO / NSLPNO / NSLPPRO1-3 / M
#   end years 2015-16  ccd_sch_129 releases, column NSLPSTATUS_CODE,
#                      codes CEO / NP / NO / P1 / P2 / P3 / M
#   end years 2017 on  ccd_sch_129 releases, column NSLP_STATUS, codes as for 2014
CEP_CODES <- c("NSLPCEO", "CEO")   # community eligibility, in either code set

# One row per school: leaid, ncessch, the reported status, and cep_school.
read_ccd_nslp <- function(path, sy_end) {
  d <- if (endsWith(tolower(path), ".csv"))
    utils::read.csv(path, colClasses = "character", na.strings = character(), check.names = FALSE)
  else
    utils::read.delim(path, colClasses = "character", quote = "\"",
                      na.strings = character(), comment.char = "", check.names = FALSE)
  up <- toupper(names(d))
  col <- function(nm) { k <- which(up == nm); if (length(k) == 1L) d[[k]] else NULL }
  status <- col("NSLPSTATUS_CODE")
  if (is.null(status)) status <- col("NSLP_STATUS")
  if (is.null(status)) status <- col("NSLPSTATUS")
  if (is.null(status)) stop(basename(path), ": no NSLP status column")
  sch <- col("NCESSCH")
  lea <- col("LEAID")
  if (is.null(sch)) stop(basename(path), ": no NCESSCH column")
  sch <- trimws(sch)
  lea <- if (is.null(lea)) substr(sch, 1, 7) else trimws(lea)
  if (!all(grepl("^[0-9]{7}$", lea))) stop(basename(path), ": LEAID not 7 digits")
  if (!all(grepl("^[0-9]{12}$", sch))) stop(basename(path), ": NCESSCH not 12 digits")
  if (anyDuplicated(sch)) stop(basename(path), ": duplicate NCESSCH")
  status <- toupper(trimws(status))
  data.frame(leaid = lea, ncessch = sch, sy_end = as.integer(sy_end), nslp_status = status,
             cep_school = as.integer(status %in% CEP_CODES), stringsAsFactors = FALSE)
}

# Preparation rule of 2.5: the district-year indicator is 1 when any school in the
# district is under CEP. A district whose schools all report a missing status is
# still 0: the CCD reports no CEP school there.
cep_district_year <- function(sch) {
  stopifnot(all(c("leaid", "sy_end", "cep_school") %in% names(sch)))
  k <- paste(sch$leaid, sch$sy_end)
  agg <- tapply(sch$cep_school, k, max)
  parts <- strsplit(names(agg), " ", fixed = TRUE)
  out <- data.frame(leaid = vapply(parts, `[`, "", 1L),
                    sy_end = as.integer(vapply(parts, `[`, "", 2L)),
                    cep = as.integer(unname(agg)), stringsAsFactors = FALSE)
  out[order(out$leaid, out$sy_end), ]
}

# The archived CCD file that carries NSLPSTATUS for an end year, and the name of
# the member to unzip. End year 2014 is the last combined school universe file.
ccd_nslp_zip <- function(sy_end) {
  if (sy_end == 2014L) "data/raw/ccd/membership-sy2013-14.zip"
  else sprintf("data/raw/ccd/school-characteristics-sy%d-%02d.zip", sy_end - 1L, sy_end %% 100L)
}

# District-year CEP indicator for one end year, read from the CCD.
cep_from_ccd <- function(sy_end, exdir = tempfile("ccdnslp")) {
  z <- ccd_nslp_zip(sy_end)
  if (!file.exists(z)) stop("missing CCD file for CEP in end year ", sy_end, ": ", z)
  dir.create(exdir, recursive = TRUE, showWarnings = FALSE)
  f <- utils::unzip(z, exdir = exdir)
  f <- f[endsWith(tolower(f), ".txt") | endsWith(tolower(f), ".csv")]
  if (length(f) != 1L) stop(basename(z), ": expected one text member, found ", length(f))
  cep_district_year(read_ccd_nslp(f, sy_end))
}

# CEP indicator for the district-years of a sample frame (leaid, state, sy_end).
# Before end year 2014 the CCD has no CEP field, so the state-level USDA phase-in
# table is used; from 2014 the indicator is the district's own CCD status. A
# district-year with no CCD school row in a CCD year is 0.
CEP_FROM_CCD <- 2014L
cep_indicator <- function(leaid, state, sy_end,
                          phase_in = "data/reference/cep_phase_in.csv") {
  stopifnot(length(leaid) == length(state), length(state) == length(sy_end))
  cep <- integer(length(leaid))
  early <- sy_end < CEP_FROM_CCD
  if (any(early)) {
    p <- utils::read.csv(phase_in, stringsAsFactors = FALSE, na.strings = character())
    cep[early] <- as.integer(sy_end[early] >= p$first_cep_sy_end[match(state[early], p$state)])
  }
  for (y in sort(unique(sy_end[!early]))) {
    d <- cep_from_ccd(y)
    k <- which(sy_end == y)
    m <- match(leaid[k], d$leaid)
    cep[k] <- ifelse(is.na(m), 0L, d$cep[m])
  }
  cep
}
