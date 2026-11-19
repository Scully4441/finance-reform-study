CDID_PACKAGE_VERSION <- "2.4.0"
CDID_POLARS_SHA <- "08ba07909a0b4968eaa3d77103c9585849a6f35d"
CDID_BASE_YEAR <- 2025L
CDID_F33_YEARS <- 2010:2024
CDID_BIN_WIDTHS <- c(bin_1000 = 1, bin_2000 = 2)
CDID_EFFECTS <- 9L
CDID_PLACEBO <- 5L
CDID_MIN_STAYERS <- 20L
CDID_MIN_STAYER_STATES <- 3L
CDID_REV_MIN_ENROLL <- 30
CDID_REV_MAX_PP <- 100
CDID_WINDOWS <- list(hs = c(2010:2019, 2021:2024), seda = c(2010:2019, 2022:2024), graduation = 2011:2021)
CDID_GAPS <- list(hs = c("a_poverty", "b_black_white", "c_hispanic_white"),
                  seda = c("a_poverty", "b_black_white", "c_hispanic_white"),
                  graduation = c("grad_black_white", "grad_hispanic_white"))
CDID_SE_CAVEAT <- paste(
  "Analytical standard errors clustered by state (DIDmultiplegtDYN 2.4.0), no bootstrap. The package's",
  "caveat that analytical errors \"can be liberal\" applies to its continuous option, which is not used:",
  "the binned revenue enters as a discrete treatment. No covariate controls (memory). Exploratory estimator.")


f33_rows <- function(d, y) {
  num <- function(v) { z <- suppressWarnings(as.numeric(v)); z[!is.na(z) & z < 0] <- NA_real_; z }
  v33 <- num(d$V33); rev <- num(d$TSTREV) + num(d$TLOCREV)
  ok <- grepl("^[0-9]{7}$", d$NCESID) & !is.na(v33) & v33 > 0 & !is.na(rev)
  out <- data.frame(leaid = d$NCESID[ok], sy_end = as.integer(y), rev_sl = rev[ok], v33 = v33[ok],
                    rev_pp = rev[ok] / v33[ok], stringsAsFactors = FALSE)
  out[!duplicated(out$leaid), , drop = FALSE]
}

f33_text_records <- function(f) max(0L, length(readLines(f, warn = FALSE)) - 1L)

f33_xlsx_rows <- function(x) {
  d <- readxl::read_excel(x, sheet = 1, col_types = "text")
  need <- c("NCESID", "V33", "TSTREV", "TLOCREV")
  if (!all(need %in% names(d))) stop(x, " lacks ", paste(setdiff(need, names(d)), collapse = ", "))
  as.data.frame(d[need])
}

f33_choose <- function(y, dir = "data/raw/f33") {
  txt <- file.path(dir, sprintf("f33-fy%d.csv", y)); x <- file.path(dir, sprintf("f33-fy%d.xlsx", y))
  have_t <- file.exists(txt); have_x <- file.exists(x)
  if (!have_t && !have_x) stop("no F-33 file for fiscal year ", y, " in ", dir)
  n_t <- if (have_t) f33_text_records(txt) else NA_integer_
  n_x <- if (have_x) nrow(f33_xlsx_rows(x)) else NA_integer_
  use_x <- have_x && (!have_t || n_x > n_t)
  data.frame(fiscal_year = as.integer(y), file = if (use_x) x else txt, records_text = n_t, records_xlsx = n_x,
             choice = if (use_x) "spreadsheet" else "text", stringsAsFactors = FALSE)
}

f33_revenue <- function(years = CDID_F33_YEARS, dir = "data/raw/f33") {
  ch <- do.call(rbind, lapply(years, f33_choose, dir = dir))
  out <- do.call(rbind, lapply(seq_len(nrow(ch)), function(i) {
    if (ch$choice[i] == "spreadsheet") f33_rows(f33_xlsx_rows(ch$file[i]), ch$fiscal_year[i]) else read_f33_revenue(ch$fiscal_year[i], dir)
  }))
  attr(out, "sources") <- ch
  out
}

cdid_real_revenue <- function(rev, cpi_file = "data/raw/cpi/cuur0000sa0.csv") {
  rev <- real_revenue(rev, cpi_file, base = CDID_BASE_YEAR)
  rev$excluded <- rev$v33 < CDID_REV_MIN_ENROLL | rev$rev_pp_real > CDID_REV_MAX_PP
  rev
}

revenue_bin <- function(x, width) floor(round(x / width, 9)) * width

quintile_revenue_gap <- function(d, rev) {
  x <- d[d$pov_quintile_2009 %in% c(1L, 5L) & !is.na(d$member_2009) & d$member_2009 > 0, , drop = FALSE]
  k <- match(paste(x$leaid, x$sy_end), paste(rev$leaid, rev$sy_end))
  x$rev <- ifelse(!is.na(k) & !rev$excluded[k], rev$rev_pp_real[k], NA_real_)
  x <- x[!is.na(x$rev), , drop = FALSE]
  key <- paste(x$state, x$sy_end)
  keys <- sort(unique(key))
  wm <- function(q) {
    f <- factor(key[x$pov_quintile_2009 == q], levels = keys)
    z <- x[x$pov_quintile_2009 == q, , drop = FALSE]
    list(v = as.vector(tapply(z$rev * z$member_2009, f, sum)) / as.vector(tapply(z$member_2009, f, sum)),
         n = as.vector(table(f)))
  }
  q5 <- wm(5L); q1 <- wm(1L)
  out <- data.frame(state = sub(" .*", "", keys), sy_end = as.integer(sub(".* ", "", keys)),
                    rev_gap = q5$v - q1$v, districts_q5 = q5$n, districts_q1 = q1$n, stringsAsFactors = FALSE)
  out <- out[out$districts_q5 > 0 & out$districts_q1 > 0, , drop = FALSE]
  rownames(out) <- NULL
  out
}

gap_a_district_years <- function(d, years) {
  x <- d[d$retained %in% 1L & d$pov_quintile_2009 %in% c(1L, 5L) & !is.na(d$member_2009) & d$member_2009 > 0,
         c("leaid", "state", "pov_quintile_2009", "member_2009"), drop = FALSE]
  stopifnot(!anyDuplicated(x$leaid))
  out <- x[rep(seq_len(nrow(x)), each = length(years)), , drop = FALSE]
  out$sy_end <- rep(as.integer(years), nrow(x))
  rownames(out) <- NULL
  out
}

hs_gap_a_districts <- function(path = "data/derived/sample_district_year.csv") {
  s <- data.table::fread(path, select = c("leaid", "state", "retained", "pov_quintile_2009"),
                         colClasses = c(leaid = "character"), data.table = FALSE, showProgress = FALSE)
  d <- unique(s)
  if (anyDuplicated(d$leaid)) stop(basename(path), ": retained or quintile differs within a district")
  td <- tempfile("ccd"); dir.create(td)
  l09 <- read_ccd_lea(utils::unzip("data/raw/ccd/lea-directory-sy2009-10.zip", exdir = td), 2010L, extra = "MEMBER")
  d$member_2009 <- ccd_count(l09$member)[match(d$leaid, l09$leaid)]
  d
}

seda_gap_a_districts <- function(seda_leaids, event_file = "data/reference/event_table.csv") {
  lea <- do.call(rbind, lapply(SEDA_RULES_WINDOW, read_ccd_lea_year))
  lea$state <- fips_to_state(lea$fipst)
  lea <- lea[!is.na(lea$state), ]
  dr <- district_rules(lea, SEDA_RULES_WINDOW)
  td <- tempfile("ccd09"); dir.create(td)
  l09 <- read_ccd_lea(utils::unzip("data/raw/ccd/lea-directory-sy2009-10.zip", exdir = td), 2010L, extra = c("GSLO", "MEMBER"))
  saipe <- read_saipe("data/raw/saipe/saipe-district-2009.txt")
  d <- data.frame(leaid = sort(union(dr$leaid, seda_leaids)), stringsAsFactors = FALSE)
  d$state <- fips_to_state(substr(d$leaid, 1, 2))
  d <- d[!is.na(d$state), , drop = FALSE]
  d$rule12 <- dr$rule12[match(d$leaid, dr$leaid)]
  d$saipe_pov_rate_2009 <- saipe$pov_rate[match(d$leaid, saipe$leaid)]
  k09 <- match(d$leaid, l09$leaid)
  d$span_3_8 <- !is.na(k09) & span_overlaps(l09$gslo[k09], l09$gshi[k09])
  d$member_2009 <- ccd_count(l09$member[k09])
  in_q <- !is.na(d$rule12) & d$rule12 == "pass" & d$span_3_8 & !is.na(d$saipe_pov_rate_2009)
  d$pov_quintile_2009 <- NA_integer_
  d$pov_quintile_2009[in_q] <- poverty_quintile(d$state[in_q], d$saipe_pov_rate_2009[in_q], d$leaid[in_q])
  ev <- utils::read.csv(event_file, stringsAsFactors = FALSE)
  d$retained <- as.integer(seda_reason(d$rule12, d$saipe_pov_rate_2009, ev$group[match(d$state, ev$state)]) == "retained")
  d$in_quintile_set <- in_q
  d
}


cdid_panel <- function(y, treat, window) {
  stopifnot(!anyDuplicated(y[c("unit", "sy_end")]), !anyDuplicated(treat[c("unit", "sy_end")]),
            all(y$sy_end %in% window))
  y <- y[!is.na(y$y), , drop = FALSE]
  units <- sort(unique(y$unit))
  st <- unique(y[c("unit", "state")])
  if (anyDuplicated(st$unit)) stop("a unit lies in more than one state")
  years <- seq(min(window), max(window))
  p <- data.frame(unit = rep(units, each = length(years)), sy_end = rep(years, length(units)), stringsAsFactors = FALSE)
  p$state <- st$state[match(p$unit, st$unit)]
  key <- paste(p$unit, p$sy_end)
  p$y <- y$y[match(key, paste(y$unit, y$sy_end))]
  p$d <- treat$d[match(key, paste(treat$unit, treat$sy_end))]
  p$placeholder <- !p$sy_end %in% window
  p[c("unit", "state", "sy_end", "y", "d", "placeholder")]
}

year_interactions <- function(p, cov, covariates, window) {
  k <- match(p$unit, cov$unit)
  vals <- cov[k, covariates, drop = FALSE]
  bad <- is.na(k) | !stats::complete.cases(vals)
  dropped <- length(unique(p$unit[bad]))
  p <- p[!bad, , drop = FALSE]; vals <- vals[!bad, , drop = FALSE]
  yrs <- sort(window)[-1]
  controls <- character()
  for (v in covariates) for (t in yrs) {
    nm <- paste0("x_", v, "_", t)
    p[[nm]] <- vals[[v]] * (p$sy_end == t)
    controls <- c(controls, nm)
  }
  rownames(p) <- NULL
  list(panel = p, controls = controls, dropped_units = dropped)
}


cdid_switch_dates <- function(p) {
  p <- p[order(p$unit, p$sy_end), , drop = FALSE]
  s <- split(p[c("sy_end", "d")], p$unit)
  do.call(rbind, lapply(names(s), function(u) {
    z <- s[[u]][!is.na(s[[u]]$d), , drop = FALSE]
    if (!nrow(z)) return(data.frame(unit = u, baseline_year = NA_integer_, baseline_d = NA_real_,
                                    first_switch = NA_real_, direction = NA_character_, stringsAsFactors = FALSE))
    ch <- which(z$d != z$d[1])
    f <- if (length(ch)) z$sy_end[ch[1]] else Inf
    data.frame(unit = u, baseline_year = z$sy_end[1], baseline_d = z$d[1], first_switch = f,
               direction = if (!length(ch)) "stayer" else if (z$d[ch[1]] > z$d[1]) "up" else "down",
               stringsAsFactors = FALSE)
  }))
}

cdid_counts <- function(p, effects = CDID_EFFECTS, placebo = CDID_PLACEBO, by_baseline = TRUE) {
  years <- sort(unique(p$sy_end))
  stopifnot(identical(years, seq(min(years), max(years))))
  units <- sort(unique(p$unit))
  n <- length(units); tn <- length(years)
  ix <- cbind(match(p$unit, units), match(p$sy_end, years))
  Y <- matrix(NA_real_, n, tn); D <- matrix(NA_real_, n, tn)
  Y[ix] <- p$y; D[ix] <- p$d
  state <- p$state[match(units, p$unit)]
  keep <- rowSums(!is.na(Y)) > 0 & rowSums(!is.na(D)) > 0
  Y <- Y[keep, , drop = FALSE]; D <- D[keep, , drop = FALSE]; state <- state[keep]; units <- units[keep]; n <- sum(keep)
  base <- rep(NA_real_, n); Fraw <- rep(Inf, n); first_row_gone <- rep(tn + 1L, n)
  last_d <- rep(NA_integer_, n); last_before <- rep(NA_integer_, n)
  for (g in seq_len(n)) {
    dn <- which(!is.na(D[g, ]))
    first <- dn[1]; base[g] <- D[g, first]
    if (first > 1) Y[g, seq_len(first - 1)] <- NA
    up <- cumsum(!is.na(D[g, ]) & D[g, ] > base[g]) > 0
    down <- cumsum(!is.na(D[g, ]) & D[g, ] < base[g]) > 0
    both <- which(up & down)
    if (length(both)) { first_row_gone[g] <- both[1]; Y[g, both[1]:tn] <- NA; D[g, both[1]:tn] <- NA; dn <- dn[dn < both[1]] }
    ch <- dn[D[g, dn] != base[g]]
    if (length(ch)) { Fraw[g] <- ch[1]; last_before[g] <- max(dn[dn < ch[1]]) }
    last_d[g] <- max(dn)
  }
  obs0 <- !is.na(Y)
  lev <- if (by_baseline) base else rep(0, n)
  lev_ok <- tapply(Fraw, lev, function(f) length(unique(f)) > 1)
  in_lev <- as.vector(lev_ok[as.character(lev)])
  switcher <- is.finite(Fraw)
  level_dropped <- !in_lev
  Y[!in_lev, ] <- NA
  row_present <- outer(seq_len(n), seq_len(tn), function(g, t) t < first_row_gone[g]) & in_lev
  not_changed <- outer(Fraw, seq_len(tn), ">")
  for (l in unique(lev[in_lev])) {
    k <- which(lev == l & in_lev)
    ok_t <- colSums(row_present[k, , drop = FALSE] & not_changed[k, , drop = FALSE]) > 0
    Y[k, !ok_t] <- NA
    row_present[k, !ok_t] <- FALSE
  }
  t_max <- max(which(colSums(row_present) > 0))
  Fi <- ifelse(switcher & last_before == Fraw - 1, Fraw, Inf)
  uncertain <- switcher & is.finite(Fraw) & last_before < Fraw - 1
  for (g in which(uncertain)) if (last_before[g] < tn) Y[g, (last_before[g] + 1):tn] <- NA
  for (g in which(!switcher)) if (last_d[g] < tn) Y[g, (last_d[g] + 1):tn] <- NA
  Ftrunc <- ifelse(uncertain, last_before + 1, ifelse(switcher, Fraw, pmin(t_max + 1, last_d + 1)))
  Tg_lev <- tapply(Ftrunc[in_lev], lev[in_lev], max) - 1
  Tg <- ifelse(in_lev, as.vector(Tg_lev[as.character(lev)]), -Inf)
  obs <- !is.na(Y)
  used <- logical(n); candidate <- logical(n)
  rows <- list()
  for (l in seq_len(effects)) {
    sw_e <- 0L; ctrl_e <- logical(n); cells_e <- 0L
    sw_p <- 0L; ctrl_p <- logical(n); cells_p <- 0L
    for (t in seq_len(tn)) {
      if (t - l < 1) next
      f <- t - l + 1
      candidate <- candidate | (Fi == f & obs0[, t] & obs0[, t - l])
      sw_all <- Fi == f & obs[, t] & obs[, t - l] & t <= Tg
      if (!any(sw_all)) next
      ctrl_all <- Fi > t & obs[, t] & obs[, t - l]
      for (lv in unique(lev[sw_all])) {
        sw <- sw_all & lev == lv
        ctrl <- ctrl_all & lev == lv
        if (!any(ctrl)) next
        sw_e <- sw_e + sum(sw); ctrl_e <- ctrl_e | ctrl; cells_e <- cells_e + sum(ctrl); used <- used | sw
        if (l <= placebo && t - 2 * l >= 1) {
          swp <- sw & obs[, t - 2 * l]; ctp <- ctrl & obs[, t - 2 * l]
          if (any(swp) && any(ctp)) { sw_p <- sw_p + sum(swp); ctrl_p <- ctrl_p | ctp; cells_p <- cells_p + sum(ctp) }
        }
      }
    }
    rows[[length(rows) + 1]] <- data.frame(row_type = "effect", package_label = paste0("Effect_", l), index = l,
      event_time = l - 1L, switchers = sw_e, stayers = sum(ctrl_e), stayer_states = length(unique(state[ctrl_e])), stayer_cells = cells_e)
    if (l <= placebo)
      rows[[length(rows) + 1]] <- data.frame(row_type = "placebo", package_label = paste0("Placebo_", l), index = l,
        event_time = -(l + 1L), switchers = sw_p, stayers = sum(ctrl_p), stayer_states = length(unique(state[ctrl_p])), stayer_cells = cells_p)
  }
  out <- do.call(rbind, rows)
  out <- out[order(out$row_type, out$index), , drop = FALSE]
  rownames(out) <- NULL
  attr(out, "switcher_units") <- data.frame(unit = units[switcher], used = used[switcher], level_dropped = level_dropped[switcher],
                                            no_stayer = (!used & (level_dropped | candidate))[switcher], stringsAsFactors = FALSE)
  out
}

cdid_estimable <- function(stayers, stayer_states)
  stayers >= CDID_MIN_STAYERS & stayer_states >= CDID_MIN_STAYER_STATES


run_cdid <- function(p, controls = character(), effects = CDID_EFFECTS, placebo = CDID_PLACEBO, continuous = NULL) {
  if (!"polars" %in% .packages()) stop("attach polars first: library(polars)")
  df <- p
  df$group_id <- as.integer(factor(df$unit))
  df$cluster_id <- as.integer(factor(df$state))
  df <- df[c("group_id", "cluster_id", "sy_end", "y", "d", controls)]
  msgs <- character()
  t0 <- proc.time()[["elapsed"]]
  fit <- tryCatch(withCallingHandlers(
    DIDmultiplegtDYN::did_multiplegt_dyn(df = df, outcome = "y", group = "group_id", time = "sy_end", treatment = "d",
      effects = effects, placebo = placebo, controls = if (length(controls)) controls else NULL, continuous = continuous,
      cluster = "cluster_id", graph_off = TRUE),
    message = function(m) { msgs <<- c(msgs, trimws(conditionMessage(m))); invokeRestart("muffleMessage") },
    warning = function(w) { msgs <<- c(msgs, trimws(conditionMessage(w))); invokeRestart("muffleWarning") }),
    error = function(e) e)
  secs <- proc.time()[["elapsed"]] - t0
  if (inherits(fit, "error")) return(list(fit = NULL, messages = unique(msgs), status = paste("error:", conditionMessage(fit)), seconds = secs))
  list(fit = fit, messages = unique(msgs), status = "ok", seconds = secs)
}

cdid_package_rows <- function(fit) {
  if (is.null(fit)) return(NULL)
  r <- fit$results
  one <- function(m) {
    if (is.null(m) || !nrow(m)) return(NULL)
    data.frame(package_label = trimws(rownames(m)), estimate = unname(m[, "Estimate"]), se = unname(m[, "SE"]),
               ci_lo = unname(m[, "LB CI"]), ci_hi = unname(m[, "UB CI"]), n = unname(m[, "N"]),
               switchers_package = unname(m[, "Switchers"]), stringsAsFactors = FALSE)
  }
  out <- rbind(one(r$Effects), one(r$Placebos), one(r$ATE))
  rownames(out) <- NULL
  out
}

cdid_results <- function(counts, pkg) {
  k <- if (is.null(pkg)) rep(NA_integer_, nrow(counts)) else match(counts$package_label, pkg$package_label)
  get <- function(col) if (is.null(pkg)) rep(NA_real_, nrow(counts)) else pkg[[col]][k]
  out <- counts
  out$estimable <- cdid_estimable(counts$stayers, counts$stayer_states)
  est <- get("estimate")
  out$status <- ifelse(is.na(k), "not estimated by the package",
                ifelse(!out$estimable, sprintf("not estimable: %d stayers in %d states (need %d in %d)", counts$stayers,
                                               counts$stayer_states, CDID_MIN_STAYERS, CDID_MIN_STAYER_STATES),
                ifelse(is.na(est), "not estimated by the package", "ok")))
  ok <- out$status == "ok"
  out$estimate <- ifelse(ok, est, NA_real_)
  out$se <- ifelse(ok, get("se"), NA_real_)
  out$ci_lo <- ifelse(ok, get("ci_lo"), NA_real_)
  out$ci_hi <- ifelse(ok, get("ci_hi"), NA_real_)
  out$n_package <- get("n")
  out$switchers_package <- get("switchers_package")
  out$switchers_match_package <- !is.na(out$switchers_package) & out$switchers == out$switchers_package
  out$n_match_package <- ifelse(out$row_type == "effect", !is.na(out$n_package) & out$switchers + out$stayer_cells == out$n_package, NA)
  out$se_caveat <- CDID_SE_CAVEAT
  out
}
