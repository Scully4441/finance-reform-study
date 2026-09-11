# Step 9. Restore the real event tables. RUN THIS YOURSELF in a plain terminal,
# only after the code is frozen:
#   git tag -a freeze -m "code frozen"
#   Rscript R/09_unblind.R
# Refuses to run without the tag or with uncommitted changes.

priv <- file.path("..", "finance-reform-study-private")
tags <- system2("git", c("tag", "-l", "freeze"), stdout = TRUE)
if (!length(tags) || !any(tags == "freeze")) stop("No 'freeze' git tag. Freeze the code first.")
dirty <- system2("git", c("status", "--porcelain"), stdout = TRUE)
if (length(dirty)) stop("Uncommitted changes present. Commit or discard them first.")
for (sfx in c("", "_r1", "_r2")) {
  real <- file.path(priv, paste0("event_table_real", sfx, ".csv"))
  if (!file.exists(real)) stop("Real event table not found: ", real)
  file.copy(real, file.path("data", "reference", paste0("event_table", sfx, ".csv")), overwrite = TRUE)
}
commit <- system2("git", c("rev-parse", "HEAD"), stdout = TRUE)
writeLines(c("REAL",
             paste("unblinded_utc:", format(Sys.time(), tz = "UTC", "%Y-%m-%dT%H:%M:%SZ")),
             paste("freeze_commit:", commit)),
           "data/reference/blinding_status.txt")
cat("Real event tables restored. Commit data/reference/ now.\n")
