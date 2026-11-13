# Starts the catalogue app for the Playwright suite.
#
#   Rscript run-app.R <port> <fixture-dir>
#
# Uses the same app and file tree as the shinytest2 catalogue tests
# (tests/testthat/helper-catalogue.R), loading this checkout of shinyFiles.

args <- commandArgs(trailingOnly = TRUE)
port <- as.integer(args[[1]])
fixture <- args[[2]]

here <- normalizePath(dirname(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))))
pkg <- normalizePath(file.path(here, "..", ".."))

library(shiny)
pkgload::load_all(pkg, quiet = TRUE, export_all = FALSE)
source(file.path(pkg, "tests", "testthat", "helper-catalogue.R"))

# helper-catalogue.R builds the tree in a new temp dir; the test runner wants
# it at a path it knows, so it can check files the dialogs create.
base <- catalogueTree()
if (dir.exists(fixture)) unlink(fixture, recursive = TRUE)
dir.create(fixture, recursive = TRUE)
file.copy(list.files(base, full.names = TRUE), fixture, recursive = TRUE)
Sys.chmod(file.path(fixture, "data", "locked"), "555")
Sys.setenv(SF_CATALOGUE_BASE = normalizePath(fixture))

app <- eval(parse(text = catalogueAppLines))
shiny::runApp(app, port = port, launch.browser = FALSE, host = "127.0.0.1")
