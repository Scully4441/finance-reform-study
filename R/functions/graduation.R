# Secondary graduation outcome (design v18, Sections 3, 5 and 6; docs/deviations.md,
# 2026-09-12). Helpers used by R/03g_graduation_sample.R, R/04g_graduation_outcomes.R and
# the graduation pass of steps 5 to 7 (`--outcome graduation`).
#
# The outcome: within-district Black-White and Hispanic-White gaps in the four-year
# adjusted cohort graduation rate (ACGR), as V = probit(rate_a) - probit(rate_b), Black
# or Hispanic minus White (the achievement orientation), from the EDFacts LEA files.
# Section 5 rule 3 applies with the cohort count in place of the tested count: the count
# must be exact and at least 30, and the rate enters exact or, as a range no wider than
# 10 points, at its midpoint (cell_status(), MAX_WIDTH); exact-only and 5-point samples
# are the robustness samples. Rule 4 (participation) has no graduation counterpart.
#
# Author decisions 2026-09-12 (docs/deviations.md; CLAUDE.md):
#   Window. End years 2011-2021, 2020 included. The loader covers the manifest's
#   2011-2024 rows; 2022-2024 have no LEA file (deviation of 2026-09-12).
#   Rules 1 and 2 over end years 2010-2021 (GRAD_RULES_WINDOW), 2009-10 included since the
#   covariates are fixed there. From 2014-15 the CCD LEA Directory has no TYPE or BOUND:
#   LEA_TYPE stands in for TYPE (1-2 regular) and UPDATED_STATUS, which uses BOUND's codes
#   1-8, for BOUND, under the same rules (2, 6, 7 not operational; 5, 8 a change).
#   Rule 6 and cohorts. The event tables' groups unchanged (excluded = a reform in
#   2005-2009); cohort_coding() over the graduation window, so a state treated in 2010 or
#   2011 has no graduation pre-period and is left out (first_year).
#   Tested-count weight. The ACGR cohort count in the gap's two groups in the first
#   graduation year, 2010-11 (GRAD_WEIGHT), fixed across years; a district without a
#   2010-11 row is left out of the weighted models alone.
#   Regression controls. cep, plus the four 2009 covariates interacted with year. The
#   test-replacement flag is an assessment flag and does not enter. cep is the step 3
#   indicator, district-year from 2014 on, so it is attached by district-year.
#   Romano-Wolf. The two graduation gaps are their own family within an event set,
#   weighting family and panel rule.

GRAD_WINDOW       <- 2011:2021   # graduation end years (deviation 2026-09-12)
GRAD_FILE_YEARS   <- 2011:2024   # manifest rows edfacts_acgr_lea
GRAD_RULES_WINDOW <- 2010:2021   # rules 1 and 2 (author decision 2026-09-12)
GRAD_SUBGROUPS    <- c("wh", "bl", "hi")
GRAD_GAPS         <- c(grad_black_white = "bw", grad_hispanic_white = "hw")   # RACE_GAPS keys
GRAD_WEIGHT       <- "cohort_2011"
GRAD_SEC_FLAGS    <- "cep"

# ---- which pass a step 5-7 run is ------------------------------------------------------

# "achievement" (the default) or "graduation", from `--outcome graduation` or
# `--outcome=graduation` on the command line.
outcome_arg <- function(args = commandArgs(trailingOnly = TRUE)) {
  val <- sub("^--outcome=", "", args[startsWith(args, "--outcome=")])
  k <- which(args == "--outcome")
  if (length(k)) {
    if (k[1] == length(args)) stop("--outcome needs a value: achievement or graduation")
    val <- c(val, args[k + 1L])
  }
  if (!length(val)) return("achievement")
  val <- unique(val)
  if (length(val) != 1L || !val %in% c("achievement", "graduation"))
    stop("--outcome must be achievement or graduation")
  val
}

# ---- EDFacts ACGR LEA files ------------------------------------------------------------

# The manifest rows of the graduation files: sy_end, path under data/raw, and whether ED
# published an LEA file (a url) for that year.
acgr_manifest <- function(manifest = "data/manifest/download_manifest.csv") {
  m <- utils::read.csv(manifest, colClasses = "character", na.strings = character(), stringsAsFactors = FALSE)
  m <- m[m$dataset == "edfacts_acgr_lea", ]
  out <- data.frame(sy_end = as.integer(m$sy_end), path = file.path("data", "raw", m$filename),
                    published = nzchar(trimws(m$url)), stringsAsFactors = FALSE)
  out[order(out$sy_end), ]
}

# A reported rate in the wide files' notation, which edfacts_range() reads: the ED Data
# Library's long files write ">=80%", "<50%", "90-94%", "93%" and "S" where the legacy
# files write GE80, LT50, 90-94, 93 and PS. Anything else stops the run.
ACGR_VALUE_OK <- "^((GE|GT|LE|LT)?[0-9]+(\\.[0-9]+)?|[0-9]+(\\.[0-9]+)?-[0-9]+(\\.[0-9]+)?|PS|N/A|\\.|)$"
acgr_value <- function(x) {
  x <- toupper(trimws(as.character(x)))
  x[is.na(x)] <- ""
  x <- gsub("%", "", x, fixed = TRUE)
  x <- sub("^>=\\s*", "GE", x); x <- sub("^<=\\s*", "LE", x)
  x <- sub("^>\\s*", "GT", x);  x <- sub("^<\\s*", "LT", x)
  x[x %in% c("S", "MISSING")] <- "PS"
  bad <- !grepl(ACGR_VALUE_OK, x)
  if (any(bad)) stop("unrecognised graduation rate value(s): ", paste(utils::head(unique(x[bad]), 10), collapse = ", "))
  x
}

# One ACGR LEA file, either layout. Returns one row per LEA: leaid, and for sg in wh, bl,
# hi the raw cohort count n_<sg> and the rate r_<sg> (acgr_value() notation), as
# character. path: a legacy .csv (wide: MWH_COHORT_1011, MWH_RATE_1011, ...) or an ED
# Data Library .zip (long: one row per LEA and subgroup, Value = rate, Denominator =
# cohort count).
read_acgr_lea <- function(path, sy_end) {
  if (endsWith(tolower(path), ".zip")) {
    td <- tempfile("acgr"); dir.create(td)
    mem <- utils::unzip(path, list = TRUE)$Name
    mem <- mem[grepl("_LEA\\.csv$", mem)]
    if (length(mem) != 1L) stop(basename(path), ": expected one *_LEA.csv member")
    return(read_acgr_long(utils::unzip(path, files = mem, exdir = td), sy_end))
  }
  read_acgr_wide(path, sy_end)
}

read_acgr_wide <- function(path, sy_end) {
  d <- data.table::fread(path, colClasses = "character", na.strings = NULL, encoding = "Latin-1",
                         showProgress = FALSE, data.table = FALSE)
  up <- toupper(names(d))
  tag <- edfacts_year_tag(sy_end)
  col <- function(sg, field) {
    k <- which(up == paste0(sg, "_", field, "_", tag))
    if (length(k) != 1L) stop(basename(path), ": expected one column ", sg, "_", field, "_", tag)
    d[[k]]
  }
  leaid <- trimws(d[[which(up == "LEAID")]])
  if (!all(grepl("^[0-9]{7}$", leaid))) stop(basename(path), ": LEAID not 7 digits")
  if (anyDuplicated(leaid)) stop(basename(path), ": duplicate LEAID")
  out <- data.frame(leaid = leaid, stringsAsFactors = FALSE)
  for (sg in c("MWH", "MBL", "MHI")) {
    s <- SUBGROUPS[[sg]]
    out[[paste0("n_", s)]] <- trimws(col(sg, "COHORT"))
    out[[paste0("r_", s)]] <- acgr_value(col(sg, "RATE"))
  }
  out
}

# Subgroup labels of the long layout, by end year of release.
ACGR_LONG_LABELS <- list(
  wh = c("White or Caucasian (not Hispanic)"),
  bl = c("Black or African American", "Black (not Hispanic) African American"),
  hi = c("Hispanic/Latino"))

read_acgr_long <- function(path, sy_end) {
  d <- data.table::fread(path, colClasses = "character", na.strings = NULL, encoding = "Latin-1",
                         showProgress = FALSE, data.table = FALSE)
  need <- c("School Year", "NCES LEA ID", "School", "Data Group", "Value", "Denominator", "Population", "Subgroup")
  miss <- setdiff(need, names(d))
  if (length(miss)) stop(basename(path), " lacks columns: ", paste(miss, collapse = ", "))
  yr <- sprintf("%d-%d", sy_end - 1L, sy_end)
  if (!all(d[["School Year"]] == yr)) stop(basename(path), ": School Year is not ", yr)
  if (any(nzchar(d$School)) || !all(d[["Data Group"]] == "695|696") || !all(d$Population == "All Students"))
    stop(basename(path), ": rows other than LEA-level four-year ACGR for all students")
  # The 2019-20 and 2020-21 releases carry a few placeholder rows per state with subgroup
  # "Missing", value MISSING, cohort 0 and no LEA ID; they describe no LEA.
  placeholder <- d$Subgroup == "Missing"
  if (any(placeholder & (d$Value != "MISSING" | d$Denominator != "0")))
    stop(basename(path), ": a 'Missing' subgroup row carries a value")
  d <- d[!placeholder, ]
  d$leaid <- trimws(d[["NCES LEA ID"]])
  if (!all(grepl("^[0-9]{7}$", d$leaid))) stop(basename(path), ": NCES LEA ID not 7 digits")
  out <- data.frame(leaid = sort(unique(d$leaid)), stringsAsFactors = FALSE)
  for (s in GRAD_SUBGROUPS) {
    x <- d[d$Subgroup %in% ACGR_LONG_LABELS[[s]], ]
    if (!nrow(x)) stop(basename(path), ": no rows for subgroup ", s)
    if (anyDuplicated(x$leaid)) stop(basename(path), ": duplicate LEA rows for subgroup ", s)
    k <- match(out$leaid, x$leaid)
    out[[paste0("n_", s)]] <- ifelse(is.na(k), "", trimws(x$Denominator[k]))
    out[[paste0("r_", s)]] <- ifelse(is.na(k), "", acgr_value(x$Value)[k])
  }
  out
}

# Every graduation year in years: the files ED published, read and stacked with sy_end.
# A year with no LEA file (no url in the manifest) is reported in `unpublished`; a
# published year whose file is missing stops the run.
load_acgr <- function(years = GRAD_FILE_YEARS, manifest = "data/manifest/download_manifest.csv") {
  m <- acgr_manifest(manifest)
  m <- m[m$sy_end %in% years, ]
  if (!setequal(m$sy_end, years)) stop("the manifest lacks graduation rows for ",
                                       paste(setdiff(years, m$sy_end), collapse = ", "))
  gone <- m$published & !file.exists(m$path)
  if (any(gone)) stop("graduation file not archived: ", paste(m$path[gone], collapse = ", "), ". Run R/02_download.R.")
  got <- lapply(m$sy_end[m$published], function(y) {
    x <- read_acgr_lea(m$path[m$sy_end == y], y)
    x$sy_end <- y
    x
  })
  list(data = do.call(rbind, got), published = m$sy_end[m$published], unpublished = m$sy_end[!m$published])
}

# Rule 3 for the graduation cells of an ACGR table (read_acgr_lea() columns): for each
# subgroup, the exact cohort count n_<sg>, rule 3 status cell_<sg> (cell_status(), with
# the cohort count as the count), range width w_<sg> in points and the rate entering the
# gap p_<sg> (exact value or range midpoint, percent; NA unless usable).
grad_cells <- function(a) {
  out <- a["leaid"]
  if ("sy_end" %in% names(a)) out$sy_end <- a$sy_end
  for (s in GRAD_SUBGROUPS) {
    n_raw <- a[[paste0("n_", s)]]; r_raw <- a[[paste0("r_", s)]]
    st <- cell_status(n_raw, r_raw)
    r <- edfacts_range(r_raw)
    out[[paste0("n_", s)]]    <- edfacts_exact(n_raw)
    out[[paste0("p_", s)]]    <- ifelse(st == "usable", r$mid, NA_real_)
    out[[paste0("w_", s)]]    <- r$width
    out[[paste0("cell_", s)]] <- st
  }
  out
}

# ---- CCD LEA directory, every layout ---------------------------------------------------

# The data member of an archived CCD LEA directory zip (the text or csv, not the SAS copy).
ccd_lea_member <- function(zip) {
  mem <- utils::unzip(zip, list = TRUE)$Name
  mem <- mem[grepl("\\.(txt|csv)$", mem, ignore.case = TRUE)]
  if (length(mem) != 1L) stop(basename(zip), ": expected one .txt or .csv member")
  mem
}

# The CCD LEA directory of one end year as read_ccd_lea() returns it (leaid, fipst,
# sy_end, agency_type, ccd_bound, gshi), whatever the layout. Through 2013-14 the
# universe file carries TYPE and BOUND (read_ccd_lea()). From 2014-15 the LEA Directory
# carries LEA_TYPE and UPDATED_STATUS instead (author decision 2026-09-12): agency_type =
# LEA_TYPE (1-9; 9, specialized district, appears from 2019-20) and ccd_bound =
# UPDATED_STATUS, whose codes 1-8 are BOUND's.
read_ccd_lea_any <- function(path, sy_end) {
  hdr <- readLines(path, n = 1L, warn = FALSE)
  sep <- if (grepl("\t", hdr, fixed = TRUE)) "\t" else ","
  fields <- toupper(strsplit(hdr, sep, fixed = TRUE)[[1]])
  if (any(fields %in% c("TYPE", sprintf("TYPE%02d", (sy_end - 1L) %% 100L)))) return(read_ccd_lea(path, sy_end))
  d <- data.table::fread(path, sep = sep, quote = "\"", colClasses = "character", na.strings = NULL,
                         encoding = "Latin-1", showProgress = FALSE, data.table = FALSE)
  n_lines <- length(readLines(path, warn = FALSE)) - 1L
  if (nrow(d) != n_lines) stop(basename(path), ": read ", nrow(d), " rows from ", n_lines, " data lines")
  need <- c("LEAID", "FIPST", "LEA_TYPE", "UPDATED_STATUS", "GSHI")
  miss <- setdiff(need, names(d))
  if (length(miss)) stop(basename(path), " lacks columns: ", paste(miss, collapse = ", "))
  leaid <- trimws(d$LEAID)
  if (!all(grepl("^[0-9]{7}$", leaid))) stop(basename(path), ": LEAID not 7 digits")
  if (anyDuplicated(leaid)) stop(basename(path), ": duplicate LEAID")
  ty <- trimws(d$LEA_TYPE); us <- trimws(d$UPDATED_STATUS)
  if (!all(ty %in% as.character(1:9)) || !all(us %in% as.character(1:8)))
    stop(basename(path), ": LEA_TYPE outside 1-9 or UPDATED_STATUS outside 1-8")
  data.frame(leaid = leaid, fipst = substr(leaid, 1, 2), sy_end = as.integer(sy_end),
             agency_type = as.integer(ty), ccd_bound = as.integer(us), gshi = trimws(d$GSHI),
             stringsAsFactors = FALSE)
}

ccd_lea_zip <- function(sy_end) sprintf("data/raw/ccd/lea-directory-sy%d-%02d.zip", sy_end - 1L, sy_end %% 100L)

read_ccd_lea_year <- function(sy_end, exdir = tempfile("ccdlea")) {
  z <- ccd_lea_zip(sy_end)
  if (!file.exists(z)) stop("missing CCD LEA directory for end year ", sy_end, ": ", z)
  dir.create(exdir, recursive = TRUE, showWarnings = FALSE)
  read_ccd_lea_any(utils::unzip(z, files = ccd_lea_member(z), exdir = exdir), sy_end)
}

# ---- gaps and panels -------------------------------------------------------------------

# Graduation gaps for one suppression sample on district-year rows of the graduation
# sample file (R/03g_graduation_sample.R): one row per district-year with at least one
# of the two gaps. v_bw = probit(p_bl) - probit(p_wh), v_hw = probit(p_hi) - probit(p_wh),
# shares clamped at 1/(2n) (v_gap()); se_* binomial sampling only. n_* are cohort counts,
# p_* rates as shares, w_* widths in points.
grad_gaps <- function(d, sample = names(MAX_WIDTH)) {
  sample <- match.arg(sample)
  ok_cell <- function(s) cell_in_sample(d[[paste0("cell_", s)]], d[[paste0("w_", s)]], sample)
  out <- data.frame(leaid = d$leaid, state = d$state, sy_end = d$sy_end, sample = rep(sample, nrow(d)),
                    retained = d$retained, retained_r1 = d$retained_r1, retained_r2 = d$retained_r2,
                    stringsAsFactors = FALSE)
  any_ok <- rep(FALSE, nrow(d))
  for (g in GRAD_GAPS) {
    a <- RACE_GAPS[[g]][1]; b <- RACE_GAPS[[g]][2]
    ok <- ok_cell(a) & ok_cell(b)
    v <- se <- rep(NA_real_, nrow(d))
    pa <- d[[paste0("p_", a)]][ok] / 100; pb <- d[[paste0("p_", b)]][ok] / 100
    na <- d[[paste0("n_", a)]][ok];       nb <- d[[paste0("n_", b)]][ok]
    v[ok]  <- v_gap(pa, pb, na, nb)
    se[ok] <- v_gap_se(pa, pb, na, nb)
    out[[paste0("v_", g)]] <- v
    out[[paste0("se_", g)]] <- se
    any_ok <- any_ok | ok
  }
  for (pre in c("n", "p", "w")) for (s in GRAD_SUBGROUPS) {
    x <- d[[paste0(pre, "_", s)]]
    out[[paste0(pre, "_", s)]] <- if (pre == "p") x / 100 else x
  }
  out <- out[any_ok, ]
  rownames(out) <- NULL
  out
}

# The graduation district-year panel for one gap and event set, as race_panel() builds
# the achievement one but with one outcome per district-year (no subjects).
# gap: "bw" or "hw"; flag: retained, retained_r1 or retained_r2. balanced = TRUE keeps
# the districts with the gap in every window year (the robustness rule). cohort_2011 is
# the fixed robustness weight: the cohort count in the gap's two groups in the first
# window year, NA for a district without a row that year.
grad_panel <- function(gaps, gap, flag, window = GRAD_WINDOW, sample = "primary", balanced = TRUE) {
  sg <- RACE_GAPS[[gap]]
  v <- paste0("v_", gap)
  x <- gaps[gaps$sample == sample & gaps[[flag]] == 1L & !is.na(gaps[[v]]) & gaps$sy_end %in% window, ]
  stopifnot(!anyDuplicated(x[c("leaid", "sy_end")]))
  out <- data.frame(leaid = x$leaid, state = x$state, sy_end = x$sy_end, y = x[[v]],
                    cohort = x[[paste0("n_", sg[1])]] + x[[paste0("n_", sg[2])]], stringsAsFactors = FALSE)
  if (balanced) {
    full <- tapply(out$sy_end, out$leaid, function(t) all(window %in% t))
    out <- out[out$leaid %in% names(full)[full], , drop = FALSE]
  }
  first <- out[out$sy_end == min(window), ]
  out[[GRAD_WEIGHT]] <- first$cohort[match(out$leaid, first$leaid)]
  out$cohort <- NULL
  out <- out[order(out$leaid, out$sy_end), , drop = FALSE]
  rownames(out) <- NULL
  out
}

# The SAIPE 2009 rate of each district in the graduation sample file, in the layout
# cs_covariates() reads (leaid, sy_end = 2010, saipe_pov_rate_2009): the rate is a
# district constant, and the graduation file has no 2009-10 row.
graduation_saipe <- function(leaids = NULL, path = "data/derived/graduation_sample_district_year.csv",
                             flag_cols = character()) {
  x <- data.table::fread(path, select = c("leaid", "saipe_pov_rate_2009"), colClasses = c(leaid = "character"),
                         data.table = FALSE, showProgress = FALSE)
  x <- unique(x)
  if (anyDuplicated(x$leaid)) stop(basename(path), ": SAIPE 2009 rate differs within a district")
  if (!is.null(leaids)) x <- x[x$leaid %in% leaids, ]
  x$sy_end <- 2010L
  x
}

# District-year controls (cep) for the regression estimators on the graduation panels.
# flags: rows with leaid, sy_end and the flag columns (the graduation sample file).
attach_district_flags <- function(panel, flags, cols = GRAD_SEC_FLAGS) {
  k <- match(paste(panel$leaid, panel$sy_end), paste(flags$leaid, flags$sy_end))
  if (anyNA(k)) stop("district-years without flags: ", sum(is.na(k)))
  x <- flags[k, cols, drop = FALSE]
  if (anyNA(x)) stop("flags missing for ", sum(!stats::complete.cases(x)), " district-years")
  panel[cols] <- x
  panel
}
