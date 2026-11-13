# Helper for scripts/run_tests.sh. Run from the package root:
#
#   Rscript scripts/run-r-stage.R unit      # tests that need no browser
#   Rscript scripts/run-r-stage.R browser   # shinytest2 tests
#   Rscript scripts/run-r-stage.R coverage  # covr line coverage of R/
#
# Prints a "RESULT ..." line the runner reads, and exits non-zero on failure.

stage <- commandArgs(trailingOnly = TRUE)[[1]]

if (stage == "coverage") {
  cov <- covr::package_coverage(".", type = "tests", quiet = TRUE)
  pct <- covr::percent_coverage(cov)
  cat(sprintf("R line coverage: %.1f%%\n", pct))
  z <- covr::zero_coverage(cov)
  if (nrow(z) > 0) {
    cat("Uncovered lines:\n")
    print(z[, c("filename", "functions", "line")], row.names = FALSE)
  }
  cat(sprintf("RESULT r_coverage=%.1f\n", pct))
  quit(status = 0)
}

pkgload::load_all(".", quiet = TRUE)
files <- list.files("tests/testthat", "^test-.*\\.R$")
browser <- grepl("-e2e\\.R$|catalogue-guard", files)
files <- switch(stage, unit = files[!browser], browser = files[browser],
                stop("unknown stage: ", stage))
names <- sub("^test-(.*)\\.R$", "\\1", files)

r <- testthat::test_dir(
  "tests/testthat",
  filter = paste0("^(", paste(names, collapse = "|"), ")$"),
  reporter = "summary", stop_on_failure = FALSE,
  package = "shinyFiles", load_package = "none"
)
d <- as.data.frame(r)
failed <- sum(d$failed > 0 | d$error)
cat(sprintf("\nRESULT tests=%d failed=%d skipped=%d errors=%d\n",
            nrow(d), sum(d$failed > 0), sum(d$skipped), sum(d$error)))
quit(status = if (failed > 0) 1 else 0)
