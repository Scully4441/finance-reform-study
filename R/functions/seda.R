SEDA_WINDOW       <- c(2009:2019, 2022:2025)
SEDA_RULES_WINDOW <- c(2010:2019, 2022:2024)
SEDA_PUBLIC_FROM  <- 2022L
SEDA_GRADES       <- 3:8
SEDA_SUBJECTS     <- c(math = "mth", rla = "rla")
SEDA_SUBGROUPS    <- c(all = "all", wh = "wht", bl = "blk", hi = "hsp")
SEDA_GAPS <- list(b_black_white = c("bl", "wh"), c_hispanic_white = c("hi", "wh"))

SEDA_RELEASES <- c(primary = "2025.2", fallback = "2025.1")
SEDA_PRE_YEARS <- 2009:2019
seda_cache <- new.env()

seda_release <- function(dir = "data/raw/seda", years_of = function(f) unique(data.table::fread(f, select = "year", showProgress = FALSE)$year)) {
  f2 <- file.path(dir, sprintf("seda_admindist_long_cs_%s.csv", SEDA_RELEASES[["primary"]]))
  f1 <- file.path(dir, sprintf("seda_admindist_long_cs_%s.csv", SEDA_RELEASES[["fallback"]]))
  if (!file.exists(f2)) return(structure(SEDA_RELEASES[["primary"]], reason = "release 2025.2 not downloaded"))
  key <- paste(normalizePath(f2), file.info(f2)$mtime)
  if (!is.null(seda_cache[[key]])) return(seda_cache[[key]])
  yrs <- years_of(f2)
  miss <- setdiff(SEDA_PRE_YEARS, yrs)
  out <- if (!length(miss)) structure(SEDA_RELEASES[["primary"]], reason = "release 2025.2 carries end years 2009-2019") else
    if (file.exists(f1)) structure(SEDA_RELEASES[["fallback"]], reason = paste("release 2025.2 lacks end years", paste(miss, collapse = " "))) else
    stop("release 2025.2 lacks end years ", paste(miss, collapse = " "), " and release 2025.1 is not downloaded")
  assign(key, out, envir = seda_cache)
  out
}

seda_long_file <- function(release = seda_release())
  sprintf("data/raw/seda/seda_admindist_long_cs_%s.csv", release)

read_seda_long <- function(path = seda_long_file()) {
  src <- as.vector(outer(c("cs_mn_", "cs_mn_se_"), SEDA_SUBGROUPS, paste0))
  need <- c("sedaadmin", "subject", "grade", "year", "fips", "stateabb", src)
  d <- data.table::fread(path, select = need, colClasses = list(character = c("sedaadmin", "subject", "stateabb")),
                         showProgress = FALSE, data.table = FALSE)
  miss <- setdiff(need, names(d))
  if (length(miss)) stop(basename(path), " lacks columns: ", paste(miss, collapse = ", "))
  id <- trimws(d$sedaadmin)
  if (!all(grepl("^[0-9]{1,7}$", id))) stop(basename(path), ": sedaadmin not a number of up to 7 digits")
  id <- formatC(as.integer(id), width = 7, flag = "0")
  pre <- substr(id, 1, 2)
  if (!all(pre == sprintf("%02d", as.integer(d$fips)) | pre == "59"))
    stop(basename(path), ": sedaadmin does not begin with the state FIPS code (or 59, BIE)")
  if (!all(d$subject %in% SEDA_SUBJECTS)) stop(basename(path), ": subject outside ", paste(SEDA_SUBJECTS, collapse = ", "))
  if (!all(d$grade %in% SEDA_GRADES)) stop(basename(path), ": grade outside 3-8")
  if (!all(d$year %in% SEDA_WINDOW)) stop(basename(path), ": year outside the SEDA window")
  out <- data.frame(leaid = id, state = d$stateabb, sy_end = as.integer(d$year),
                    subject = names(SEDA_SUBJECTS)[match(d$subject, SEDA_SUBJECTS)],
                    grade = as.integer(d$grade), stringsAsFactors = FALSE)
  if (anyDuplicated(out[c("leaid", "sy_end", "subject", "grade")]))
    stop(basename(path), ": duplicate district-year-subject-grade")
  for (sg in names(SEDA_SUBGROUPS)) {
    out[[paste0("mn_", sg)]] <- as.numeric(d[[paste0("cs_mn_", SEDA_SUBGROUPS[[sg]])]])
    out[[paste0("se_", sg)]] <- as.numeric(d[[paste0("cs_mn_se_", SEDA_SUBGROUPS[[sg]])]])
  }
  out
}

seda_pool <- function(x) {
  key <- paste(x$leaid, x$sy_end, x$subject, sep = "|")
  ukey <- unique(key)
  f <- factor(key, levels = ukey)
  first <- match(ukey, key)
  out <- x[first, c("leaid", "state", "sy_end", "subject")]
  rownames(out) <- NULL
  for (sg in names(SEDA_SUBGROUPS)) {
    m <- x[[paste0("mn_", sg)]]; s <- x[[paste0("se_", sg)]]
    ok <- !is.na(m) & !is.na(s) & s > 0
    w <- ifelse(ok, 1 / s^2, 0)
    sw <- as.vector(rowsum(w, f, reorder = FALSE))
    swm <- as.vector(rowsum(ifelse(ok, w * m, 0), f, reorder = FALSE))
    out[[paste0("mn_", sg)]] <- ifelse(sw > 0, swm / sw, NA_real_)
    out[[paste0("se_", sg)]] <- ifelse(sw > 0, 1 / sqrt(sw), NA_real_)
    out[[paste0("grades_", sg)]] <- as.integer(rowsum(as.integer(ok), f, reorder = FALSE))
    out[[paste0("gmask_", sg)]] <- as.integer(rowsum(ifelse(ok, 2L^(x$grade - 3L), 0L), f, reorder = FALSE))
  }
  for (g in names(SEDA_GAPS)) {
    a <- SEDA_GAPS[[g]][1]; b <- SEDA_GAPS[[g]][2]
    ma <- x[[paste0("mn_", a)]]; sa <- x[[paste0("se_", a)]]; mb <- x[[paste0("mn_", b)]]; sb <- x[[paste0("se_", b)]]
    ok <- !is.na(ma) & !is.na(sa) & sa > 0 & !is.na(mb) & !is.na(sb) & sb > 0
    w <- ifelse(ok, 1 / (sa^2 + sb^2), 0)
    sw <- as.vector(rowsum(w, f, reorder = FALSE))
    pm <- function(m) ifelse(sw > 0, as.vector(rowsum(ifelse(ok, w * m, 0), f, reorder = FALSE)) / sw, NA_real_)
    ps <- function(s) ifelse(sw > 0, sqrt(as.vector(rowsum(ifelse(ok, w^2 * s^2, 0), f, reorder = FALSE))) / sw, NA_real_)
    out[[paste0("mn_", a, "_", g)]] <- pm(ma); out[[paste0("mn_", b, "_", g)]] <- pm(mb)
    out[[paste0("se_", a, "_", g)]] <- ps(sa); out[[paste0("se_", b, "_", g)]] <- ps(sb)
    out[[paste0("grades_", g)]] <- as.integer(rowsum(as.integer(ok), f, reorder = FALSE))
  }
  out
}

seda_subject_wide <- function(x, keys, carry = character()) {
  sides <- lapply(names(SEDA_SUBJECTS), function(subj) {
    y <- x[x$subject == subj, c(keys, "value", "se", carry), drop = FALSE]
    names(y) <- c(keys, paste0(c("v", "se", carry), "_", subj))
    y
  })
  w <- merge(sides[[1]], sides[[2]], by = keys, all = TRUE, sort = FALSE)
  w$v <- (w$v_math + w$v_rla) / 2
  w[c(keys, "v", as.vector(t(outer(c("v", "se", carry), names(SEDA_SUBJECTS), paste, sep = "_"))))]
}

seda_race_gaps <- function(p) {
  do.call(rbind, lapply(names(SEDA_GAPS), function(g) {
    a <- SEDA_GAPS[[g]][1]; b <- SEDA_GAPS[[g]][2]
    ga <- paste0("_", a, "_", g); gb <- paste0("_", b, "_", g)
    ok <- !is.na(p$mn_all) & !is.na(p[[paste0("mn", ga)]]) & !is.na(p[[paste0("mn", gb)]])
    y <- p[ok, ]
    if (!nrow(y)) return(NULL)
    y$value <- y[[paste0("mn", ga)]] - y[[paste0("mn", gb)]]
    y$se <- sqrt(y[[paste0("se", ga)]]^2 + y[[paste0("se", gb)]]^2)
    y$mean_all <- y$mn_all; y$se_all <- y$se_all; y$grades_all <- y$grades_all
    y$mean_group <- y[[paste0("mn", ga)]]; y$se_group <- y[[paste0("se", ga)]]; y$grades_group <- y[[paste0("grades_", g)]]
    y$mean_wh <- y[[paste0("mn", gb)]]; y$se_wh <- y[[paste0("se", gb)]]; y$grades_wh <- y[[paste0("grades_", g)]]
    carry <- as.vector(outer(c("mean", "se", "grades"), c("all", "group", "wh"), paste, sep = "_"))
    w <- seda_subject_wide(y, c("leaid", "state", "sy_end"), carry)
    cbind(gap = rep(g, nrow(w)), w, stringsAsFactors = FALSE)
  }))
}

seda_poverty_gap <- function(p, dist) {
  k <- match(p$leaid, dist$leaid)
  x <- p[!is.na(k), ]
  x$q <- dist$pov_quintile_2009[k[!is.na(k)]]
  x$member <- dist$member_2009[k[!is.na(k)]]
  x <- x[x$q %in% c(1L, 5L) & !is.na(x$member) & x$member > 0 & !is.na(x$mn_all), ]
  if (!nrow(x)) return(NULL)
  x$key <- paste(x$state, x$sy_end, x$subject, sep = "|")
  keys <- unique(x$key)
  by_q <- function(qq) {
    y <- x[x$q == qq, ]
    f <- factor(y$key, levels = keys)
    sw <- as.vector(tapply(y$member, f, sum))
    list(score = as.vector(tapply(y$member * y$mn_all, f, sum)) / sw,
         se = sqrt(as.vector(tapply(y$member^2 * y$se_all^2, f, sum))) / sw,
         districts = as.vector(table(f)))
  }
  lo <- by_q(1L); hi <- by_q(5L)
  first <- x[match(keys, x$key), c("state", "sy_end", "subject")]
  y <- data.frame(first, value = hi$score - lo$score, se = sqrt(hi$se^2 + lo$se^2),
                  mean_q5 = hi$score, mean_q1 = lo$score, districts_q5 = hi$districts, districts_q1 = lo$districts,
                  stringsAsFactors = FALSE)
  y <- y[y$districts_q1 > 0 & y$districts_q5 > 0, ]
  if (!nrow(y)) return(NULL)
  w <- seda_subject_wide(y, c("state", "sy_end"), c("mean_q5", "mean_q1", "districts_q5", "districts_q1"))
  cbind(gap = rep("a_poverty", nrow(w)), w, stringsAsFactors = FALSE)
}

ccd_grade_num <- function(x) {
  x <- toupper(trimws(x))
  out <- suppressWarnings(as.numeric(x))
  out[!grepl("^[0-9]{1,2}$", x)] <- NA_real_
  out[x == "PK"] <- -1
  out[x == "KG"] <- 0
  out
}

span_overlaps <- function(gslo, gshi, lo = min(SEDA_GRADES), hi = max(SEDA_GRADES)) {
  a <- ccd_grade_num(gslo); b <- ccd_grade_num(gshi)
  !is.na(a) & !is.na(b) & a <= hi & b >= lo
}

SEDA_NO_SAIPE <- "no SAIPE 2009 poverty rate"
seda_reason <- function(rule12, pov_rate, group) {
  r <- ifelse(is.na(rule12), "rule 2: not operational in every window year", rule12)
  ifelse(r != "pass", r,
         ifelse(is.na(pov_rate), SEDA_NO_SAIPE,
                ifelse(group == "excluded", "rule 6: state excluded (reform in 2005-2009)", "retained")))
}
