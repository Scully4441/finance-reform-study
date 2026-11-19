if (!requireNamespace("testthat", quietly = TRUE)) stop("testthat is not installed; run renv::restore()")
res <- testthat::test_dir("tests/testthat", reporter = testthat::ProgressReporter$new(show_praise = FALSE),
                          stop_on_failure = FALSE, load_helpers = TRUE)
df <- as.data.frame(res)
cat(sprintf("\nExpectations: %d passed, %d failed; tests with errors: %d; skipped: %d\n",
            sum(df$passed), sum(df$failed), sum(df$error), sum(df$skipped)))
if (sum(df$failed) > 0L || any(df$error)) quit(save = "no", status = 1L)
cat("All tests passed.\n")
