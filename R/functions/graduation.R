GRAD_WINDOW       <- 2011:2021
GRAD_FILE_YEARS   <- 2011:2024
GRAD_RULES_WINDOW <- 2011:2021
GRAD_SUBGROUPS    <- c("wh", "bl", "hi")
GRAD_GAPS         <- c(grad_black_white = "bw", grad_hispanic_white = "hw")
GRAD_WEIGHT       <- "cohort_2011"
GRAD_SEC_FLAGS    <- "cep"


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


acgr_manifest <- function(manifest = "data/manifest/download_manifest.csv") {
  m <- utils::read.csv(manifest, colClasses = "character", na.strings = character(), stringsAsFactors = FALSE)
  m <- m[m$dataset == "edfacts_acgr_lea", ]
  out <- data.frame(sy_end = as.integer(m$sy_end), path = file.path("data", "raw", m$filename),
                    published = nzchar(trimws(m$url)), stringsAsFactors = FALSE)
  out[order(out$sy_end), ]
}

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


ccd_lea_member <- function(zip) {
  mem <- utils::unzip(zip, list = TRUE)$Name
  mem <- mem[grepl("\\.(txt|csv)$", mem, ignore.case = TRUE)]
  if (length(mem) != 1L) stop(basename(zip), ": expected one .txt or .csv member")
  mem
}

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

attach_district_flags <- function(panel, flags, cols = GRAD_SEC_FLAGS) {
  k <- match(paste(panel$leaid, panel$sy_end), paste(flags$leaid, flags$sy_end))
  if (anyNA(k)) stop("district-years without flags: ", sum(is.na(k)))
  x <- flags[k, cols, drop = FALSE]
  if (anyNA(x)) stop("flags missing for ", sum(!stats::complete.cases(x)), " district-years")
  panel[cols] <- x
  panel
}
