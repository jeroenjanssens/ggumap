# Plan: submit ggumap 0.1.0 to CRAN

Decisions (2026-11-22):

* Benchmarks (bench/, the README "Performance" section, the benchmarks
  article) stay out of this release; they remain uncommitted for now.
* Keep the minimum Rust version at 1.90.
* Keep palmerpenguins (Suggests) for the vignette and README.
* Claude may push to `main`.

Status legend: [x] done, [ ] to do, [~] needs Jeroen.

## Phase 1: Blocking fixes

- [x] 1.1 Commit the pending feature work without the benchmark changes:
      reject geoms that need their own statistic, embed facet-copied rows
      once, `umap_embed()` + regular geom in docs, tests and snapshots.
- [x] 1.2 `MASS` in Suggests. Examples, vignette and visual test that use
      `geom_density_2d_filled()` only run when MASS is installed.
      (Cause of both ERRORs in `R CMD check --as-cran`: with
      `_R_CHECK_SUGGESTS_ONLY_` undeclared packages are unavailable.)
- [x] 1.3 PDF manual WARNING: local only (TeX not on PATH in non-login
      shells; `R CMD Rd2pdf` succeeds with TinyTeX on PATH). Confirm on
      win-builder and in a Debian container (see 4.4), because raylibr
      6.0.5 was rejected on exactly this warning.

## Phase 2: DESCRIPTION, metadata, docs

- [x] 2.1 Quote software names in Description ('Rust').
- [x] 2.2 `Copyright:` field pointing at `inst/AUTHORS` (as raylibr does
      for inst/COPYRIGHTS).
- [x] 2.3 `.Rbuildignore`: `^CRAN-SUBMISSION$`, `^\.claude$`.
- [x] 2.4 Every exported function and S3 method documents its return value.
- [x] 2.5 Spelling (`spelling::spell_check_package()`, add `inst/WORDLIST`).
- [x] 2.6 URLs (`urlchecker::url_check()`), incl. https://ggumap.jeroenjanssens.com/.
- [x] 2.7 Example timings: each Rd < 5 s elapsed, CPU/elapsed < 2.5 under
      `_R_CHECK_LIMIT_CORES_`.
- [x] 2.8 NEWS.md describes 0.1.0 as released (incl. the new geom check).

## Phase 3: Rust

- [x] 3.1 Vendored crates, offline build, `-j 2`, CARGO_HOME in src/ and
      removed afterwards, rustc/cargo versions printed (already in place).
- [x] 3.2 Look up the rustc version on CRAN's check machines and record
      it in cran-comments.md (MSRV 1.90 is kept; `ordered-float` 5.5.1
      needs 1.90, `wide`/`safe_arch` 1.89).
- [x] 3.3 Re-check that installation leaves no `src/.cargo`, `src/vendor`
      or `src/rust/target` behind and never touches the network.
- [ ] 3.4 (Open question, not changed) `cargo run --bin document` at
      install time: keep for now, as in the rextendr template.

## Phase 4: Checks

- [x] 4.1 Local `R CMD check --as-cran` with `_R_CHECK_LIMIT_CORES_=TRUE`
      and TeX on PATH: 0 errors, 0 warnings, 1 note (new submission).
- [x] 4.2 GitHub Actions green: macOS, Windows, Ubuntu devel/release/oldrel,
      rustc 1.90 offline.
- [x] 4.3 R-hub v2 workflow (`.github/workflows/rhub.yaml`) and runs on:
      linux, macos-arm64, windows, nosuggests, clang-asan, clang-ubsan,
      gcc-asan, valgrind, rchk. All OK except nosuggests (container BLAS
      hangs on any matrix product; not ggumap, see log).
- [x] 4.4 PDF manual in a Debian container (R-devel + TeX Live).
- [~] 4.5 win-builder R-devel and R-release (uploaded 81b2d1f), mac-builder
      (HTTP 502 three times; retry).
      [~] Results arrive by email at jeroen@jeroenjanssens.com: paste them.

## Phase 5: Submission

- [x] 5.1 cran-comments.md in raylibr's structure: submission, bundled
      code, Rust, examples/tests/threads, test environments with exact
      versions, results.
- [~] 5.2 `devtools::submit_cran()` and click the confirmation email.
- [~] 5.3 Answer reviewers. Every resubmission bumps the version
      (0.1.1, ...) and gets a "Resubmission" section; never move tags.
- [ ] 5.4 After acceptance: tag v0.1.0, GitHub release,
      `usethis::use_dev_version()`, CRAN badge in README.

## Log

* 2026-11-22: rustc on CRAN (from gifski's install logs): Debian 1.98.1,
  Fedora 1.99.1, Windows (Rtools) 1.92.0, macOS release 1.93.0, but
  **macOS oldrel (arm64 and x86_64) 1.84.1**. 1.84 is not reachable
  without patching Apple's `nndescent` (needs `wide` 1.x = 1.89 and
  `getrandom` 0.4 = 1.85); only `ordered-float` could be downgraded. MSRV
  stays 1.90: ggumap will not install on the two oldrel macOS flavours.
  Stated in cran-comments.md.
* 2026-11-22: local `R CMD check --as-cran` (clean `git archive` of HEAD,
  `_R_CHECK_LIMIT_CORES_=TRUE`, TinyTeX on PATH): 0 errors, 0 warnings,
  2 notes (new submission; HTML Tidy too old locally, R-hub `vnu` covers
  HTML validation). Examples: stat_umap 1.0 s elapsed. Tests 14 s.
  Install 50 s; offline, `-j 2`, no `.cargo`/`vendor`/`target` left.
* 2026-11-22: the PDF-manual WARNING of the first run was local: `tex`
  was not on PATH in the non-login shell. With TinyTeX on PATH it is OK.
* 2026-11-22: `umap_threads()` also honours `OMP_THREAD_LIMIT` (extra
  safety against the CPU/elapsed NOTE on flavours without
  `_R_CHECK_LIMIT_CORES_`).
* 2026-11-22: Debian container (r-base, R 4.6.2, TeX Live 2026/Debian):
  `R CMD Rd2pdf` exit 0, 100 KB PDF, 40 KB log (only inconsolata italic
  font-substitution warnings). Tarball piped via stdin: Docker Desktop
  does not share /tmp or /private/tmp here.
* 2026-11-22: GitHub Actions all green on eda2c7f (5 R CMD check jobs,
  rustc 1.90 offline, rust, lint, format, coverage, pkgdown).
* 2026-11-22: R-hub run 1 (eda2c7f): OK on linux, windows, macos-arm64,
  m1-san, gcc16, lto, valgrind (status OK). Failures:
  - clang-asan, clang-ubsan, clang23, rchk, vnu: `tar xf vendor.tar.xz`
    needs an `xz` binary, which those containers lack. Fixed in e92984e:
    Makevars unpack with `untar(tar = "internal")`. Verified locally
    with failing `tar`/`xz` stubs first on PATH, and in the Fedora 44
    nosuggests container.
  - gcc-asan, nosuggests (both Fedora 44): hung in `R CMD build`
    ("installing the package ... creating vignettes") until the 6 h
    GitHub limit. Not reproduced locally in the nosuggests image
    (install, embeddings with 1 and 2 threads, a full ggplot build all
    finish in seconds). Rerun with a 90-min timeout.
  - valgrind: no invalid reads/writes or uninitialised values. 165 bytes
    "definitely lost" from extendr's Err -> R error path (longjmp over
    Rust frames) in tests that raise errors on purpose. Not fixable in
    ggumap; leave.
* 2026-11-22: install-time `cargo run --bin document` builds all crates a
  second time in the dev profile: 28 s (vs. 14 s release) on macOS,
  1 min 27 s (vs. 53 s) in the Fedora container. Recommend removing it
  from Makevars (open question 3.4).
* 2026-11-22: win-builder R-devel and R-release uploaded (eda2c7f/cef26da
  package code; results by email). mac-builder upload failed twice with
  HTTP 502 (server side); retry later.
* 2026-11-23: R-hub run 2 (internal untar): rchk, clang-asan,
  clang-ubsan, clang23, vnu now OK. valgrind: same leak-only report
  (status OK). gcc-asan and nosuggests hung again (90-min timeout).
* 2026-11-23: both hangs diagnosed with a temporary debug workflow
  (branch `debug-fedora-hang`, deleted afterwards):
  - gcc-asan: `Rscript -e 'system("rustc --version", intern = TRUE)'`
    hangs in the ASAN build of R when `rustc` is rustup's proxy; calling
    it from bash works. With Fedora's own `rust`/`cargo` (1.100, dnf) the
    whole `R CMD build` incl. vignette takes 3 min. Not a ggumap bug; the
    R-hub workflow now installs Rust with dnf in Fedora containers.
  - nosuggests: the container's BLAS (FlexiBLAS OPENBLAS-OPENMP,
    `OMP_THREAD_LIMIT=2`) hangs on any matrix product, also without
    ggumap loaded: `m %*% m` for a 500x500 matrix and `MASS::kde2d()`
    both time out, also with `OPENBLAS_NUM_THREADS=1`. The vignette's
    `density` chunk is the first to do a matrix product. Not a ggumap
    bug; nosuggests is left out of further runs. (Could be reported to
    r-hub/containers.)
* 2026-11-23: R-hub on final package code: gcc-asan, gcc16, lto OK with
  Fedora's Rust; valgrind OK (same 165-byte extendr leak); linux, windows,
  macos-arm64, m1-san OK. GitHub Actions green on 81b2d1f.
* 2026-11-23: final local `--as-cran` on 81b2d1f: 0 errors, 0 warnings,
  3 notes (new submission; HTML Tidy local; "unable to verify current
  time" = time-server lookup failed). stat_umap examples 0.87 s, tests
  13 s, install 46 s. win-builder re-uploaded with this code.

## Still open

* [~] win-builder emails (R-devel and R-release, for 81b2d1f): paste into
  cran-comments.md, replacing the TODO line.
* [~] mac-builder: retry `devtools::check_mac_release()` when it accepts
  uploads again (optional; R-hub macos-arm64/m1-san and GitHub macOS pass).
* [ ] 3.4 decide on `cargo run --bin document` at install time (doubles
  build time).
* [~] Optional: report the nosuggests BLAS hang to r-hub/containers.
* [~] Submit: `devtools::submit_cran()`, confirm the email.
* 2026-11-24: all benchmarks redone on AC power (Apple M4 Pro, ggumap at
  81b2d1f): full suite 48 min, README suite 13 min, no failed runs.
  Committed in b611141 (tooling) and 1c4b64d (results, article, README
  Performance section). The README's claims still hold. The package
  tarball gains README-benchmark.png (74 KB) and the README section; the
  win-builder uploads predate this but the package code is unchanged.
