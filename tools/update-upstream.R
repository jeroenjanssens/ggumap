# Update the bundled UMAP implementation to a new commit of
# apple/embedding-atlas, re-vendor the Rust dependencies and regenerate
# inst/AUTHORS. Then run the tests and benchmarks before releasing.
#
# Usage (from the package root):
#   Rscript tools/update-upstream.R            # latest commit on main
#   Rscript tools/update-upstream.R <sha>      # a specific commit
args <- commandArgs(trailingOnly = TRUE)
repo <- "https://github.com/apple/embedding-atlas"

sha <- if (length(args)) {
  args[[1]]
} else {
  out <- system2("git", c("ls-remote", repo, "refs/heads/main"), stdout = TRUE)
  sub("\\s.*$", "", out[[1]])
}
stopifnot(grepl("^[0-9a-f]{40}$", sha))

files <- c("src/rust/Cargo.toml", "src/rust/src/lib.rs", "tools/vendor.sh")
old <- regmatches(
  readLines("src/rust/Cargo.toml"),
  regexpr("[0-9a-f]{40}", readLines("src/rust/Cargo.toml"))
)[[1]]
if (identical(old, sha)) {
  message("Already at ", sha)
  quit(status = 0)
}
for (f in files) {
  txt <- readLines(f)
  writeLines(gsub(old, sha, txt, fixed = TRUE), f)
}
message("Updated ", substr(old, 1, 7), " -> ", substr(sha, 1, 7))

run <- function(cmd, args, ...) {
  status <- system2(cmd, args, ...)
  if (!identical(status, 0L)) stop(cmd, " failed")
}
run(
  "cargo",
  c("update", "--manifest-path", "src/rust/Cargo.toml", "-p", "umap")
)
run("sh", "tools/vendor.sh")
source("tools/authors.R")
message(
  "Done. Next: review the upstream changes (",
  repo,
  "/compare/",
  old,
  "...",
  sha,
  "), update NEWS.md, run devtools::test(), R CMD check and the benchmarks."
)
