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

SUBGROUPS <- c(ALL = "all", MWH = "wh", MBL = "bl", MHI = "hi", ECD = "ecd")
SUBJECTS  <- c(math = "MTH", rla = "RLA")

edfacts_year_tag <- function(sy_end) sprintf("%02d%02d", (sy_end - 1L) %% 100L, sy_end %% 100L)


read_ccd_lea <- function(path, sy_end, extra = character()) {
  n_lines <- length(readLines(path, warn = FALSE)) - 1L
  d <- utils::read.delim(path, colClasses = "character", quote = "\"",
                         na.strings = character(), comment.char = "")
  if (!"TYPE" %in% names(d))
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

ACH_WINDOW <- c(2010:2019, 2021L)
ach_window <- function(stage) if (identical(as.integer(stage), 1L)) ACH_WINDOW[ACH_WINDOW <= STAGE1_LAST_YEAR] else ACH_WINDOW
PART_FROM  <- 2013L

edfacts_hs_file <- function(subject, sy_end, kind = c("achievement", "participation")) {
  kind <- match.arg(kind)
  sprintf("data/raw/edfacts/%s-%s-lea-sy%d-%02d%s.csv", subject, kind, sy_end - 1L, sy_end %% 100L,
          if (sy_end == 2019L) "-long" else "")
}

read_edfacts_hs <- function(path, subject, sy_end, kind = c("achievement", "participation")) {
  kind <- match.arg(kind)
  code <- SUBJECTS[[subject]]
  hdr <- toupper(gsub("\"", "", strsplit(readLines(path, n = 1L, warn = FALSE), ",", fixed = TRUE)[[1]]))
  if (all(c("GRADE", "CATEGORY") %in% hdr)) return(read_edfacts_hs_long(path, subject, sy_end, kind))
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

read_edfacts_hs_long <- function(path, subject, sy_end, kind) {
  code <- SUBJECTS[[subject]]
  fields <- if (kind == "achievement") c(n = "NUMVALID", p = "PCTPROF") else c(part = "PCTPART")
  need <- c("SCHOOL_YEAR", "LEAID", "SUBJECT", "GRADE", "CATEGORY", unname(fields))
  d <- data.table::fread(path, colClasses = "character", na.strings = NULL, select = need,
                         showProgress = FALSE, data.table = FALSE)
  miss <- setdiff(need, names(d))
  if (length(miss)) stop(basename(path), " lacks columns: ", paste(miss, collapse = ", "))
  yr <- sprintf("%d-%d", sy_end - 1L, sy_end)
  if (!all(d$SCHOOL_YEAR == yr)) stop(basename(path), ": SCHOOL_YEAR is not ", yr)
  if (!all(d$SUBJECT == code)) stop(basename(path), ": SUBJECT is not ", code)
  d$LEAID <- trimws(d$LEAID)
  if (!all(grepl("^[0-9]{7}$", d$LEAID))) stop(basename(path), ": LEAID not 7 digits")
  hs <- d[d$GRADE == "HS", ]
  if (!nrow(hs)) stop(basename(path), ": no GRADE HS rows")
  out <- data.frame(leaid = sort(unique(hs$LEAID)), stringsAsFactors = FALSE)
  for (sg in names(SUBGROUPS)) {
    x <- hs[hs$CATEGORY == sg, ]
    if (anyDuplicated(x$LEAID)) stop(basename(path), ": duplicate LEAID for ", sg)
    k <- match(out$leaid, x$LEAID)
    for (f in names(fields))
      out[[paste0(f, "_", SUBGROUPS[[sg]])]] <- ifelse(is.na(k), "", x[[fields[[f]]]][k])
  }
  out
}

read_saipe <- function(path) {
  x <- iconv(readLines(path, warn = FALSE), from = "latin1", to = "UTF-8")
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


MAX_WIDTH <- c(primary = 10, r5 = 5, exact = 0)

cell_status <- function(n_raw, p_raw, floor = 30, max_width = MAX_WIDTH[["primary"]]) {
  n <- edfacts_exact(n_raw)
  w <- edfacts_range(p_raw)$width
  ifelse(is.na(n), "not_reported",
         ifelse(n < floor, "below_30",
                ifelse(is.na(w), "suppressed",
                       ifelse(w > max_width, "wide_range", "usable"))))
}

cell_in_sample <- function(status, width, sample = names(MAX_WIDTH)) {
  sample <- match.arg(sample)
  status == "usable" & !is.na(width) & width <= MAX_WIDTH[[sample]]
}

part_value <- function(x) edfacts_range(x)$mid

part_pass <- function(x, threshold = 95) {
  v <- part_value(x)
  !is.na(v) & v >= threshold
}

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


CEP_CODES <- c("NSLPCEO", "CEO")

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

ccd_nslp_zip <- function(sy_end) {
  if (sy_end == 2014L) "data/raw/ccd/membership-sy2013-14.zip"
  else sprintf("data/raw/ccd/school-characteristics-sy%d-%02d.zip", sy_end - 1L, sy_end %% 100L)
}

cep_from_ccd <- function(sy_end, exdir = tempfile("ccdnslp")) {
  z <- ccd_nslp_zip(sy_end)
  if (!file.exists(z)) stop("missing CCD file for CEP in end year ", sy_end, ": ", z)
  dir.create(exdir, recursive = TRUE, showWarnings = FALSE)
  f <- utils::unzip(z, exdir = exdir)
  f <- f[endsWith(tolower(f), ".txt") | endsWith(tolower(f), ".csv")]
  if (length(f) != 1L) stop(basename(z), ": expected one text member, found ", length(f))
  cep_district_year(read_ccd_nslp(f, sy_end))
}

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

part_straddles <- function(x) {
  pr <- edfacts_range(x)
  !is.na(pr$width) & pr$width > 0 & pr$lo < 95 & pr$hi >= 95
}

HS_RULES_WINDOW <- c(2010:2019, 2021:2024)
hs_rules_window <- function(stage) if (identical(as.integer(stage), 1L)) ach_window(1L) else HS_RULES_WINDOW

EDFACTS_2019_CANDIDATES <- c(ed = "data/raw/edfacts/%s-%s-lea-sy2018-19.zip", archive = "data/raw/edfacts/%s-%s-lea-sy2018-19-long.csv")
EDL_SUBGROUP_PATTERNS <- c(ALL = "^All Students", MWH = "^White", MBL = "^Black", MHI = "^Hispanic", ECD = "^Economically Disadvantaged")

read_edfacts_hs_edl <- function(path, subject, sy_end, kind = c("achievement", "participation")) {
  kind <- match.arg(kind)
  td <- tempfile("edl"); dir.create(td); on.exit(unlink(td, recursive = TRUE), add = TRUE)
  files <- utils::unzip(path, exdir = td)
  files <- files[grepl("\\.csv$", files, ignore.case = TRUE)]
  if (!length(files)) stop(basename(path), ": no CSV member")
  need <- c("School Year", "NCES LEA ID", "Value", "Denominator", "Subgroup", "Age/Grade", "Academic Subject")
  d <- do.call(rbind, lapply(files, function(f) {
    x <- data.table::fread(f, colClasses = "character", na.strings = NULL, showProgress = FALSE, data.table = FALSE, check.names = FALSE)
    miss <- setdiff(need, names(x))
    if (length(miss)) stop(basename(f), " lacks columns: ", paste(miss, collapse = ", "))
    x[need]
  }))
  subj_pat <- if (subject == "math") "^Math" else "Reading|Language"
  d <- d[grepl("high school", d[["Age/Grade"]], ignore.case = TRUE) & grepl(subj_pat, d[["Academic Subject"]], ignore.case = TRUE), , drop = FALSE]
  if (!nrow(d)) stop(basename(path), ": no high school rows for ", subject)
  d$leaid <- trimws(d[["NCES LEA ID"]])
  d <- d[grepl("^[0-9]{7}$", d$leaid), , drop = FALSE]
  out <- data.frame(leaid = sort(unique(d$leaid)), stringsAsFactors = FALSE)
  for (sg in names(SUBGROUPS)) {
    x <- d[grepl(EDL_SUBGROUP_PATTERNS[[sg]], d$Subgroup), , drop = FALSE]
    if (anyDuplicated(x$leaid)) stop(basename(path), ": duplicate LEA rows for ", sg)
    k <- match(out$leaid, x$leaid)
    val <- ifelse(is.na(k), "", acgr_value(x$Value[k]))
    if (kind == "achievement") {
      out[[paste0("n_", SUBGROUPS[[sg]])]] <- ifelse(is.na(k), "", trimws(x$Denominator[k]))
      out[[paste0("p_", SUBGROUPS[[sg]])]] <- val
    } else out[[paste0("part_", SUBGROUPS[[sg]])]] <- val
  }
  out
}

edfacts_states_covered <- function(d) sort(unique(stats::na.omit(fips_to_state(substr(d$leaid, 1, 2)))))

edfacts_2019_read <- function(subject, kind = c("achievement", "participation"), candidates = EDFACTS_2019_CANDIDATES) {
  kind <- match.arg(kind)
  log <- data.frame(copy = character(), file = character(), states = integer(), covers_all = logical(), note = character(),
                    stringsAsFactors = FALSE)
  got <- list()
  for (nm in names(candidates)) {
    f <- sprintf(candidates[[nm]], subject, kind)
    if (!file.exists(f)) { log[nrow(log) + 1L, ] <- list(nm, f, NA_integer_, FALSE, "file not present"); next }
    d <- tryCatch(if (grepl("\\.zip$", f)) read_edfacts_hs_edl(f, subject, 2019L, kind) else read_edfacts_hs(f, subject, 2019L, kind),
                  error = function(e) e)
    if (inherits(d, "error")) { log[nrow(log) + 1L, ] <- list(nm, f, NA_integer_, FALSE, conditionMessage(d)); next }
    st <- edfacts_states_covered(d)
    all51 <- all(names(STATE_FIPS) %in% st)
    log[nrow(log) + 1L, ] <- list(nm, f, length(intersect(st, names(STATE_FIPS))), all51, "")
    got[[nm]] <- d
  }
  pick <- log$copy[log$covers_all][1]
  if (is.na(pick)) stop("no 2019 ", subject, " ", kind, " file covers the 50 states and DC")
  structure(got[[pick]], choice = pick, choice_log = log)
}
