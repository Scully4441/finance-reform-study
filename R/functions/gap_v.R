clamp_share <- function(p, n = NULL) {
  ok <- is.na(p) | (p >= 0 & p <= 1)
  if (!all(ok)) stop("shares must lie in [0, 1]; percentages must be divided by 100 first")
  if (is.null(n)) return(p)
  eps <- 1 / (2 * n)
  pmin(pmax(p, eps), 1 - eps)
}

v_gap <- function(p_a, p_b, n_a = NULL, n_b = NULL) {
  qnorm(clamp_share(p_a, n_a)) - qnorm(clamp_share(p_b, n_b))
}

probit_score <- function(p, n = NULL) qnorm(clamp_share(p, n))

v_gap_se <- function(p_a, p_b, n_a, n_b) {
  p_a <- clamp_share(p_a, n_a)
  p_b <- clamp_share(p_b, n_b)
  vp <- function(p, n) p * (1 - p) / (n * dnorm(qnorm(p))^2)
  sqrt(vp(p_a, n_a) + vp(p_b, n_b))
}
