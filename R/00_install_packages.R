# Step 0. Install the packages named in the design document and record versions.
#   Rscript R/00_install_packages.R
# Some packages are not always on CRAN; those fall back to GitHub.
# Windows needs Rtools for the GitHub installs.

cran <- c("data.table", "digest", "future", "furrr", "testthat", "remotes",
          "renv", "did", "fixest", "didimputation", "fwildclusterboot",
          "wildrwolf", "HonestDiD")
github <- c(synthdid = "synth-inference/synthdid",
            fwildclusterboot = "s3alfisc/fwildclusterboot",
            wildrwolf = "s3alfisc/wildrwolf",
            HonestDiD = "asheshrambachan/HonestDiD")

for (p in cran) {
  if (!requireNamespace(p, quietly = TRUE)) try(install.packages(p))
}
for (p in names(github)) {
  if (!requireNamespace(p, quietly = TRUE)) try(remotes::install_github(github[[p]]))
}

all_pkgs <- union(cran, names(github))
have <- vapply(all_pkgs, requireNamespace, logical(1), quietly = TRUE)
if (any(!have)) {
  message("Not installed: ", paste(all_pkgs[!have], collapse = ", "))
  message("Fix these before continuing.")
}
versions <- data.frame(
  package = all_pkgs,
  version = vapply(all_pkgs, function(p) if (have[[p]]) as.character(packageVersion(p)) else NA_character_, character(1)),
  r_version = R.version.string,
  recorded_utc = format(Sys.time(), tz = "UTC", "%Y-%m-%dT%H:%M:%SZ"),
  stringsAsFactors = FALSE)
dir.create("outputs", showWarnings = FALSE)
write.csv(versions, "outputs/package_versions.csv", row.names = FALSE)
print(versions[, c("package", "version")], row.names = FALSE)
