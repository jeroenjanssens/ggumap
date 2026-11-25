## Submission

This is a new submission.

ggumap adds a statistic and a geometry to ggplot2 that compute UMAP
embeddings (McInnes, Healy and Melville, 2018) inside a plot layer, and a
function, `umap_embed()`, that returns the embedding as a data frame.

## Bundled code (Rust)

* The UMAP and nearest-neighbour code is Apple's Rust port of umap-learn
  and PyNNDescent (crates `umap` and `nndescent` from
  <https://github.com/apple/embedding-atlas>, MIT, pinned to commit
  a0d0f09). Apple Inc. is listed in Authors@R with role "cph".
* All Rust dependencies are vendored in `src/rust/vendor.tar.xz` (1.7 MB).
  It was created with `cargo vendor-filterer` (`tools/vendor.sh` in the
  repository), which keeps only the crates needed on the platforms R runs
  on and leaves out tests, benchmarks, examples and the unused GPU stack.
* The authors, versions and licences of all vendored crates are listed in
  `inst/AUTHORS` (see the Copyright field), and in Authors@R as "Authors of
  the dependency Rust crates" (role "ctb"). `LICENSE.note` explains the
  licensing. All crates are available under the MIT licence.
* The R wrappers of the Rust functions are committed
  (`R/extendr-wrappers.R`); they are only regenerated in development builds
  (`NOT_CRAN` set), so installation compiles the Rust code once.
* The build follows CRAN's policy for Rust: it runs offline (`--offline`)
  with at most 2 jobs (`-j 2`), `CARGO_HOME` is a temporary directory in
  `src/` that is removed after the build, the vendored sources and the
  target directory are removed after installation, and `configure`
  (`tools/msrv.R`) prints the `cargo` and `rustc` versions.
* The compiled code does not print: progress is reported through R (cli).
  Panics are caught and turned into R errors, and long computations
  check for user interrupts.

## Minimum Rust version

SystemRequirements declares rustc >= 1.90, which is needed by the vendored
crates (`ordered-float`, and `wide`, which Apple's `nndescent` requires).
All current CRAN check machines we could look up have a newer rustc,
except the two r-oldrel-macos flavours (rustc 1.84.1), on which ggumap
will not install. Supporting 1.84 would require patching Apple's code.

## Examples, tests and threads

* Examples, tests and the vignette use at most 2 threads: the default
  number of threads, `umap_threads()`, is limited to 2 when
  `_R_CHECK_LIMIT_CORES_` is set and to `OMP_THREAD_LIMIT` when that is
  set. The tests and vignette use 1 thread.
* The slowest example (`stat_umap()`) takes 0.6 s locally and at most
  4.6 s on win-builder.
* Tests of interrupt handling (which need a child R process) and visual
  snapshot tests (whose floating-point output differs across platforms)
  are skipped on CRAN.
* Nothing is downloaded by the examples, tests or vignette.

## Test environments

* Local: macOS 27 (aarch64), R 4.5.1, rustc 1.99.1,
  `R CMD check --as-cran` with `_R_CHECK_LIMIT_CORES_=TRUE`, including the
  PDF manual.
* Debian container (R 4.6.2, TeX Live 2026/Debian): `R CMD Rd2pdf` of the
  PDF manual (exit status 0, 40 KB of LaTeX output).
* GitHub Actions: macOS (R release), Windows (R release), Ubuntu (R devel,
  release and oldrel-1), and Ubuntu with rustc 1.90 (the declared minimum)
  installing offline from the vendored crates.
* R-hub (R-devel), Status: OK on linux, windows, macos-arm64, m1-san,
  gcc16, clang23, lto, gcc-asan, clang-asan, clang-ubsan, rchk, vnu and
  valgrind. The sanitizer builds report no runtime errors. valgrind
  reports no invalid reads or writes and no use of uninitialised values;
  it reports 165 bytes "definitely lost" in tests that raise errors on
  purpose, where extendr turns a Rust error into an R error with a
  longjmp over Rust frames.
* win-builder: R-release (4.6.2) and R-devel (2026-11-17 r90926 ucrt):
  1 NOTE each (new submission, and the words explained below); the
  slowest example takes 2.4 s and 4.6 s there.

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.
* Possibly misspelled words in DESCRIPTION: "Healy" and "McInnes" are the
  names of the authors of the cited UMAP paper, "UMAP" is the name of the
  method (spelled out in the Description), and "embeddings" is the
  standard term for its results.
