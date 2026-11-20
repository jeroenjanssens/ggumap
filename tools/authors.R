# Regenerate inst/AUTHORS from the Rust dependency graph. CRAN requires the
# authors and licences of all bundled (vendored) code to be listed.
# Run from the package root after tools/vendor.sh.
`%||%` <- function(a, b) if (is.null(a)) b else a
meta <- jsonlite::fromJSON(
  system2(
    "cargo",
    c(
      "metadata",
      "--format-version",
      "1",
      "--manifest-path",
      "src/rust/Cargo.toml"
    ),
    stdout = TRUE
  ),
  simplifyVector = FALSE
)
vendored <- utils::untar("src/rust/vendor.tar.xz", list = TRUE)
vendored <- unique(sub(
  "^vendor/([^/]+)/.*$",
  "\\1",
  vendored[grepl("^vendor/[^/]+/", vendored)]
))
pkgs <- Filter(function(p) p$name != "ggumap", meta$packages)
lines <- vapply(
  pkgs,
  function(p) {
    dir <- if (p$name %in% vendored) p$name else paste0(p$name, "-", p$version)
    if (!dir %in% vendored && !p$name %in% vendored) {
      return(NA_character_)
    }
    authors <- if (length(p$authors)) {
      paste(unlist(p$authors), collapse = ", ")
    } else {
      paste("The", p$name, "developers")
    }
    sprintf(
      "- %s %s (%s): %s%s",
      p$name,
      p$version,
      p$license %||% "see crate",
      authors,
      if (is.null(p$repository)) "" else paste0(" <", p$repository, ">")
    )
  },
  character(1)
)
lines <- sort(unique(stats::na.omit(lines)))
header <- c(
  "The ggumap package bundles the following Rust crates (in src/rust/vendor.tar.xz).",
  "Listed are the crate name, version, licence, and authors as declared by each crate.",
  "",
  "The UMAP and NNDescent implementations (crates `umap` and `nndescent`) are",
  "Copyright (c) 2025 Apple Inc., MIT licence, from https://github.com/apple/embedding-atlas.",
  ""
)
dir.create("inst", showWarnings = FALSE)
writeLines(c(header, lines), "inst/AUTHORS")
cat(length(lines), "crates written to inst/AUTHORS\n")
