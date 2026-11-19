options(repos = c(CRAN = "https://cloud.r-project.org"), Ncpus = 4)

if (!requireNamespace("renv", quietly = TRUE)) stop("renv is not installed; open R in the repository folder so renv/activate.R bootstraps it")
renv::restore(lockfile = "renv.lock", prompt = FALSE)

locked <- renv::lockfile_read("renv.lock")$Packages
pkgs <- sort(names(locked))
have <- vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)
versions <- data.frame(
  package = pkgs,
  version = vapply(pkgs, function(p) if (have[[p]]) as.character(utils::packageVersion(p)) else NA_character_, character(1)),
  locked_version = vapply(pkgs, function(p) as.character(locked[[p]]$Version), character(1)),
  source = vapply(pkgs, function(p) as.character(locked[[p]]$Source), character(1)),
  r_version = R.version.string,
  recorded_utc = format(Sys.time(), tz = "UTC", "%Y-%m-%dT%H:%M:%SZ"),
  stringsAsFactors = FALSE)
dir.create("outputs", showWarnings = FALSE)
utils::write.csv(versions, "outputs/package_versions.csv", row.names = FALSE)
bad <- versions$package[is.na(versions$version) | versions$version != versions$locked_version]
if (length(bad)) stop("installed versions differ from renv.lock for: ", paste(bad, collapse = ", "))
cat(nrow(versions), "packages restored at their renv.lock versions; versions in outputs/package_versions.csv\n")
