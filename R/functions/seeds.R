MASTER_SEED <- 130L

seed_for <- function(step) {
  stopifnot(is.character(step), length(step) == 1L, nzchar(step))
  p <- 2147483647
  h <- as.numeric(MASTER_SEED)
  for (b in utf8ToInt(step)) h <- (h * 31 + b) %% p
  as.integer(h)
}
