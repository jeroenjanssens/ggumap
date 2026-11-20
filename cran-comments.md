## Submission

This is a new package.

## Test environments

* local macOS (aarch64), R 4.5.1, rustc 1.99.1
* GitHub Actions: macOS (release), Windows (release), Ubuntu (devel, release,
  oldrel-1), and Ubuntu with rustc 1.90 (the declared minimum version)
* win-builder (devel) — to do before submission
* mac-builder — to do before submission

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## Rust

* The package contains Rust code, compiled with cargo. All dependencies are
  vendored in `src/rust/vendor.tar.xz` and the build runs offline
  (`--offline`), with at most 2 jobs (`-j 2`), and with `CARGO_HOME` set to a
  temporary directory inside `src/` that is removed after the build.
* `rustc` and `cargo` versions are printed during configure (`tools/msrv.R`),
  and the minimum version (1.90) is declared in `SystemRequirements`.
* The authors and licences of all vendored crates are listed in
  `inst/AUTHORS`; see also `LICENSE.note`. The bundled UMAP implementation is
  Copyright Apple Inc. (MIT), who are listed as copyright holder in
  `Authors@R`.
* Examples, tests and vignettes use at most 2 threads; the default number of
  threads is capped at 2 when `_R_CHECK_LIMIT_CORES_` is set.
