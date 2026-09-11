# Callaway-Sant'Anna primary estimator (design document, Section 7).
# Helpers used by R/05_primary.R on the step 4 outputs
# (data/derived/gaps_race_district_year.csv, data/derived/gap_poverty_state_year.csv).
# Author decisions 2026-09-11 (docs/decision_log.md):
#   The outcome is the mean of math and RLA V in a unit-year; a unit-year needs both.
#   Unbalanced panel (author, 2026-09-11, replacing the balanced-panel rule of the same
#   day): a unit enters with the outcome in any window year, and did::att_gt runs with
#   allow_unbalanced_panel = TRUE. The balanced panel, where a unit needs the outcome in
#   every window year, is kept as a robustness model (PANEL_TYPES).
#   Covariates for gaps (b) and (c): log 2009-10 CCD membership, the SAIPE 2009
#   child-poverty rate, and the Black and Hispanic shares of 2009-10 CCD school
#   membership. Gap (a) has none. The test-replacement and CEP flags do not enter:
#   did::att_gt conditions on baseline covariates only.
#   Tested-count weights (robustness, gaps (b) and (c)): students tested in the gap's
#   two groups in the first window year (2009-10), averaged over math and RLA, fixed
#   across years.

EVENT_MIN <- -5L   # event times reported (Section 7); -1 is the reference period
EVENT_MAX <- 8L
CS_COVARIATES <- c("log_member_2009", "saipe_pov_rate_2009", "black_share_2009", "hisp_share_2009")
# The two panel rules of step 5, named as they appear in the `panel` column of the step 5
# files and in the model keys. The value is did's allow_unbalanced_panel: the unbalanced
# panel is the primary model and the balanced panel the robustness one (author decision
# 2026-09-11).
PANEL_TYPES <- c(unbalanced = TRUE, balanced = FALSE)

# did's cohort variable from one event table (columns state, treat_year, group).
# One row per state: g (0 = not treated within the window) and cohort_status:
#   never         never-treated control, g = 0
#   estimable     treated after the first window year and no later than the last
#   after_window  treated after the last window year: no post-period in the window,
#                 so a not-yet-treated control in every window year, g = 0
#   first_year    treated in the first window year: no pre-period, so it can neither
#                 be estimated nor serve as a control; left out (did would drop it)
#   excluded      rule 6 (reform in 2005-2009); left out
cohort_coding <- function(ev, window) {
  stopifnot(all(ev$group %in% c("treated", "never", "excluded")),
            !anyNA(ev$treat_year[ev$group == "treated"]), !anyDuplicated(ev$state))
  ty <- ev$treat_year
  status <- ifelse(ev$group == "excluded", "excluded",
            ifelse(ev$group == "never", "never",
            ifelse(ty > max(window), "after_window",
            ifelse(ty <= min(window), "first_year", "estimable"))))
  g <- ifelse(status == "estimable", ty, ifelse(status %in% c("never", "after_window"), 0L, NA_integer_))
  data.frame(state = ev$state, g = as.integer(g), cohort_status = status, stringsAsFactors = FALSE)
}

# Mean of math and RLA V within a unit-year (Section 6), then the estimation panel.
# x: rows of one gap file, already restricted to one sample, one event set and a
# non-missing `value`. A unit-year needs both subjects (author decision 2026-09-11).
# balanced = TRUE additionally keeps only the units with an outcome in every window
# year (the robustness panel); balanced = FALSE keeps every unit-year (the primary
# panel, estimated with allow_unbalanced_panel = TRUE). carry: further columns averaged
# over subjects. Returns unit, state, sy_end, y and the carried columns.
both_subjects <- function(x, unit, value, window, carry = character(), balanced = TRUE) {
  key  <- unique(c(unit, "state", "sy_end"))
  keep <- c(key, value, carry)
  m <- x[x$subject == "math", keep, drop = FALSE]
  r <- x[x$subject == "rla", keep, drop = FALSE]
  stopifnot(!anyDuplicated(m[c(unit, "sy_end")]), !anyDuplicated(r[c(unit, "sy_end")]))
  y <- merge(m, r, by = key, suffixes = c("_math", "_rla"))
  out <- y[key]
  out$y <- (y[[paste0(value, "_math")]] + y[[paste0(value, "_rla")]]) / 2
  for (cc in carry) out[[cc]] <- (y[[paste0(cc, "_math")]] + y[[paste0(cc, "_rla")]]) / 2
  out <- out[out$sy_end %in% window, , drop = FALSE]
  if (balanced) {
    full <- tapply(out$sy_end, out[[unit]], function(t) all(window %in% t))
    out <- out[out[[unit]] %in% names(full)[full], , drop = FALSE]
  }
  out <- out[order(out[[unit]], out$sy_end), , drop = FALSE]
  rownames(out) <- NULL
  out
}

# Gaps (b) and (c): the district-year panel for one event set, unbalanced (the primary
# rule) or balanced over the window (the robustness rule).
# gap: "bw" or "hw" (RACE_GAPS); flag: retained, retained_r1 or retained_r2.
# tested_2010 is the fixed robustness weight: students tested in the gap's two
# groups in the first window year, averaged over math and RLA. On the unbalanced panel a
# district with no first-window-year row has no such weight and gets NA, which leaves it
# out of the weighted models only (author decision 2026-09-11); on the balanced panel
# every district has one.
race_panel <- function(gaps, gap, flag, window, sample = "primary", balanced = TRUE) {
  sg <- RACE_GAPS[[gap]]
  v <- paste0("v_", gap)
  x <- gaps[gaps$sample == sample & gaps[[flag]] == 1L & !is.na(gaps[[v]]), ]
  x$tested <- x[[paste0("n_", sg[1])]] + x[[paste0("n_", sg[2])]]
  out <- both_subjects(x, "leaid", v, window, carry = "tested", balanced = balanced)
  w <- out$tested[out$sy_end == min(window)]
  out$tested_2010 <- w[match(out$leaid, out$leaid[out$sy_end == min(window)])]
  out$tested <- NULL
  out
}

# Gap (a): the state-year panel for one event set, unbalanced or balanced as above.
pov_panel <- function(pov, flag, window, sample = "primary", balanced = TRUE) {
  x <- pov[pov$sample == sample & pov[[flag]] == 1L & !is.na(pov$v_pov), ]
  both_subjects(x, "state", "v_pov", window, balanced = balanced)
}

# Black and Hispanic shares of district membership from a CCD school universe flat
# file (2009-10: sc092a, names suffixed "09"). Schools are summed within LEAID over
# those reporting valid BLACK, HISP and total-by-race (TOTETH) counts; the shares are
# BLACK / TOTETH and HISP / TOTETH, all grades. CCD negative codes are missing.
read_ccd_race_shares <- function(path, sy_end) {
  sfx <- sprintf("%02d", (sy_end - 1L) %% 100L)
  need <- c("LEAID", paste0(c("BLACK", "HISP", "TOTETH"), sfx))
  n_lines <- length(readLines(path, warn = FALSE)) - 1L
  d <- data.table::fread(path, sep = "\t", quote = "\"", colClasses = "character", select = need,
                         showProgress = FALSE, data.table = FALSE)
  if (nrow(d) != n_lines) stop(basename(path), ": read ", nrow(d), " rows from ", n_lines, " data lines")
  miss <- setdiff(need, names(d))
  if (length(miss)) stop(basename(path), " lacks columns: ", paste(miss, collapse = ", "))
  names(d) <- sub(paste0(sfx, "$"), "", names(d))
  d$LEAID <- trimws(d$LEAID)
  if (!all(grepl("^[0-9]{7}$", d$LEAID))) stop(basename(path), ": LEAID not 7 digits")
  b <- ccd_count(d$BLACK); h <- ccd_count(d$HISP); t <- ccd_count(d$TOTETH)
  ok <- !is.na(b) & !is.na(h) & !is.na(t) & t > 0
  if (any(b[ok] + h[ok] > t[ok])) stop(basename(path), ": BLACK + HISP exceeds TOTETH")
  agg <- stats::aggregate(data.frame(black = b[ok], hisp = h[ok], toteth = t[ok]),
                          list(leaid = d$LEAID[ok]), sum)
  data.frame(leaid = agg$leaid, black_share = agg$black / agg$toteth, hisp_share = agg$hisp / agg$toteth,
             schools = as.vector(table(d$LEAID[ok])[agg$leaid]), stringsAsFactors = FALSE)
}

# Covariates for gaps (b) and (c), all fixed at 2009-10 (author decisions 2026-09-11):
# log 2009-10 CCD membership (MEMBER), the SAIPE 2009 child-poverty rate, and the
# Black and Hispanic shares of 2009-10 CCD school membership. leaids: the districts
# to cover; smp: rows of data/derived/sample_district_year.csv with leaid, sy_end and
# saipe_pov_rate_2009. Returns one row per district with CS_COVARIATES (NA where
# invalid). Shared by steps 5 and 6.
cs_covariates <- function(leaids, smp, sy_end = 2010L,
                          lea_zip = "data/raw/ccd/lea-directory-sy2009-10.zip",
                          mem_zip = "data/raw/ccd/membership-sy2009-10.zip") {
  td <- tempfile("ccd"); dir.create(td)
  l09 <- read_ccd_lea(utils::unzip(lea_zip, exdir = td), sy_end, extra = "MEMBER")
  rs  <- read_ccd_race_shares(utils::unzip(mem_zip, exdir = td), sy_end)
  cov <- data.frame(leaid = sort(unique(leaids)), stringsAsFactors = FALSE)
  m09 <- ccd_count(l09$member)[match(cov$leaid, l09$leaid)]
  m09[!is.na(m09) & m09 <= 0] <- NA_real_
  cov$log_member_2009 <- log(m09)
  s09 <- smp[smp$sy_end == sy_end, ]
  cov$saipe_pov_rate_2009 <- s09$saipe_pov_rate_2009[match(cov$leaid, s09$leaid)]
  cov$black_share_2009 <- rs$black_share[match(cov$leaid, rs$leaid)]
  cov$hisp_share_2009  <- rs$hisp_share[match(cov$leaid, rs$leaid)]
  cov
}

# Attach did's cohort variable to a panel (unit column `unit`) and drop the units
# whose state cannot enter (cohort_status first_year or excluded). Adds g,
# cohort_status and an integer id. Returns the panel and the dropped unit count
# by status.
attach_cohorts <- function(panel, coding, unit) {
  k <- match(panel$state, coding$state)
  if (anyNA(k)) stop("states missing from the event table: ", paste(unique(panel$state[is.na(k)]), collapse = " "))
  panel$g <- coding$g[k]
  panel$cohort_status <- coding$cohort_status[k]
  out <- panel$cohort_status %in% c("first_year", "excluded")
  dropped <- tapply(panel[[unit]][out], factor(panel$cohort_status[out], levels = c("first_year", "excluded")),
                    function(z) length(unique(z)))
  dropped[is.na(dropped)] <- 0L
  panel <- panel[!out, , drop = FALSE]
  panel$id <- as.integer(factor(panel[[unit]]))
  rownames(panel) <- NULL
  list(panel = panel, dropped = dropped)
}

# One Callaway-Sant'Anna model: did::att_gt with not-yet-treated controls, the
# doubly robust estimator and a universal base period (event time -1 is the
# reference), standard errors clustered by state through did's multiplier bootstrap
# (seeded with seed_for(seed_step)); then did::aggte's dynamic aggregation over event
# times min_e..max_e and its overall post-reform average.
# allow_unbalanced_panel is passed to did::att_gt: TRUE is the primary model, where a
# unit enters with the outcome in any window year and did estimates each ATT(g, t) from
# the units observed in the two periods it compares; FALSE is the balanced-panel
# robustness model and takes a panel already restricted to complete units.
# panel: id (integer), state, sy_end, y, g (0 = not treated within the window) and
# any covariates or weight column. A model without an estimable cohort, or one that
# did cannot fit, returns a status instead of stopping.
# Returns status, notes (did's warnings and messages), event (one row per event time
# with the cohorts, treated states and treated units behind it), overall, cells
# (ATT(g, t)) and fit (the att_gt and aggte objects).
run_cs <- function(panel, xformla = ~1, weightsname = NULL, seed_step,
                   min_e = EVENT_MIN, max_e = EVENT_MAX, allow_unbalanced_panel = FALSE) {
  stopifnot(all(c("id", "state", "sy_end", "y", "g") %in% names(panel)), is.integer(panel$id),
            !anyNA(panel[c("id", "sy_end", "y", "g")]), !anyDuplicated(panel[c("id", "sy_end")]))
  if (!is.null(weightsname))
    stopifnot(all(is.finite(panel[[weightsname]])), all(panel[[weightsname]] > 0),
              all(tapply(panel[[weightsname]], panel$id, function(w) length(unique(w)) == 1L)))
  notes <- character()
  ev <- data.frame(e = min_e:max_e, att = NA_real_, se = NA_real_, crit_val = NA_real_,
                   ci_lo = NA_real_, ci_hi = NA_real_, cohorts = 0L, treated_states = 0L,
                   treated_units = 0L, reference = (min_e:max_e) == -1L)
  overall <- data.frame(att = NA_real_, se = NA_real_, ci_lo = NA_real_, ci_hi = NA_real_,
                        cohorts = 0L, treated_states = 0L, treated_units = 0L)
  cells <- data.frame(g = integer(), t = integer(), e = integer(), att = numeric(), se = numeric())
  result <- function(status) list(status = status, notes = unique(notes), event = ev, overall = overall,
                                  cells = cells, fit = fit)
  fit <- NULL
  if (!any(panel$g > 0)) return(result("no estimable cohort"))

  set.seed(seed_for(seed_step))
  fit <- tryCatch(withCallingHandlers({
    gt <- did::att_gt(yname = "y", tname = "sy_end", idname = "id", gname = "g", data = panel,
                      xformla = xformla, weightsname = weightsname, control_group = "notyettreated",
                      est_method = "dr", base_period = "universal", clustervars = "state", bstrap = TRUE,
                      allow_unbalanced_panel = allow_unbalanced_panel)
    es <- did::aggte(gt, type = "dynamic", min_e = min_e, max_e = max_e, na.rm = TRUE)
    list(att_gt = gt, aggte = es)
  }, warning = function(w) {
    notes <<- c(notes, trimws(conditionMessage(w))); invokeRestart("muffleWarning")
  }, message = function(m) {
    notes <<- c(notes, trimws(conditionMessage(m))); invokeRestart("muffleMessage")
  }), error = function(e) e)
  if (inherits(fit, "error")) {
    msg <- conditionMessage(fit)
    fit <- NULL
    return(result(paste("error:", msg)))
  }

  gt <- fit$att_gt; es <- fit$aggte
  cells <- data.frame(g = as.integer(gt$group), t = as.integer(gt$t), e = as.integer(gt$t - gt$group),
                      att = gt$att, se = gt$se)
  if (anyNA(cells$att)) notes <- c(notes, paste(sum(is.na(cells$att)),
                                                "group-time cells without an estimate, left out of the aggregation"))
  est <- cells[!is.na(cells$att), ]
  treated <- panel[panel$g > 0, ]
  count_for <- function(gs) c(cohorts = length(gs),
                              treated_states = length(unique(treated$state[treated$g %in% gs])),
                              treated_units = length(unique(treated$id[treated$g %in% gs])))
  cnt <- t(vapply(ev$e, function(e) count_for(unique(est$g[est$e == e])), numeric(3)))
  ev[c("cohorts", "treated_states", "treated_units")] <- lapply(as.data.frame(cnt), as.integer)
  k <- match(ev$e, es$egt)
  ev$att <- es$att.egt[k]
  ev$se  <- es$se.egt[k]
  ev$crit_val <- if (length(es$crit.val.egt) == 1L) es$crit.val.egt else NA_real_
  ev$ci_lo <- ev$att - ev$crit_val * ev$se
  ev$ci_hi <- ev$att + ev$crit_val * ev$se
  z <- stats::qnorm(1 - 0.05 / 2)
  post <- count_for(unique(est$g[est$e >= 0 & est$e <= max_e]))
  overall <- data.frame(att = es$overall.att, se = es$overall.se,
                        ci_lo = es$overall.att - z * es$overall.se, ci_hi = es$overall.att + z * es$overall.se,
                        cohorts = as.integer(post[["cohorts"]]), treated_states = as.integer(post[["treated_states"]]),
                        treated_units = as.integer(post[["treated_units"]]))
  result("ok")
}
