ROOT <- normalizePath(file.path("..", ".."), winslash = "/", mustWork = TRUE)
for (f in list.files(file.path(ROOT, "R", "functions"), full.names = TRUE)) source(f, local = globalenv())

near <- function(a, b, tol = 1e-8) all(abs(a - b) < tol)

expect_all <- function(...) {
  labels <- vapply(as.list(substitute(list(...)))[-1], function(e) paste(deparse(e, width.cutoff = 500L), collapse = " "), "")
  values <- list(...)
  for (i in seq_along(values))
    testthat::expect_true(isTRUE(all(values[[i]])) && !anyNA(values[[i]]), label = labels[i])
  invisible(TRUE)
}

sim <- function(n = 30, effect = 0.5) {
  ty <- c(2011L, 2012L, 2012L, 2013L, 2016L, 2010L, NA, NA, NA)
  ev <- data.frame(state = sprintf("S%02d", seq_along(ty)), treat_year = ty,
                   group = ifelse(is.na(ty), "never", "treated"), stringsAsFactors = FALSE)
  set.seed(seed_for("test primary sim"))
  d <- expand.grid(k = seq_len(n), state = ev$state, sy_end = 2010:2013, stringsAsFactors = FALSE)
  d$unit <- paste(d$state, d$k)
  u <- sort(unique(d$unit)); x <- stats::rnorm(length(u)); w <- 50 + 10 * (seq_along(u) %% 7)
  d$x1 <- x[match(d$unit, u)]; d$w <- w[match(d$unit, u)]
  tyd <- ev$treat_year[match(d$state, ev$state)]
  d$y <- 0.3 * d$x1 + 0.05 * (d$sy_end - 2010) + effect * (!is.na(tyd) & d$sy_end >= tyd) +
    stats::rnorm(nrow(d), sd = 0.02)
  ac <- attach_cohorts(d[order(d$unit, d$sy_end), ], cohort_coding(ev, 2010:2013), "unit")
  ac
}
