# Seeds (design document, Section 8).
# One master integer. Every stochastic step derives its own seed from it by
# name, so results do not depend on the order in which steps run.
# The blinding permutation does NOT use this file; its seed is held by the
# author outside the repository.

MASTER_SEED <- 130L

seed_for <- function(step) {
  stopifnot(is.character(step), length(step) == 1L, nzchar(step))
  p <- 2147483647              # 2^31 - 1
  h <- as.numeric(MASTER_SEED)
  for (b in utf8ToInt(step)) h <- (h * 31 + b) %% p
  as.integer(h)
}
