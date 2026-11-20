# Plan: a ggplot2 extension for UMAP backed by Apple's Rust implementation

Working name: **`ggumap`** (not on CRAN as of 2026-11-20; alternatives: `umapr`, `ggUMAP`).
Status: plan only, nothing implemented.

---

## 1. Upstream: what we are wrapping

| Item | Finding |
|---|---|
| Repo / commit | `apple/embedding-atlas`, `main` @ `a0d0f0938db386a86dc855182df3432e1814891d` (2026-11-20) |
| Crates | `packages/umap/umap` (UMAP) + `packages/umap/nndescent` (approximate kNN, PyNNDescent port) |
| License | MIT, © 2025 Apple Inc. |
| Published? | No, not on crates.io. Must use a **git dependency pinned to `rev`** and vendor it |
| API | `Umap::builder(&Array2<f32>)` → `UmapBuilder` → `.build()` → `UmapResult { embedding, knn_indices, knn_distances }`. Also `Umap::builder_from_knn(idx, dist)` for a precomputed kNN graph |
| Parameters | `n_neighbors` (15), `n_components` (2), `min_dist` (0.1), `spread` (1), `metric` ("euclidean"), `n_epochs`, `learning_rate`, `negative_sample_rate`, `repulsion_strength`, `local_connectivity`, `set_op_mix_ratio`, `random_state`, `init_method` (auto/spectral/tswspectral/pca/random/recursive/custom), `optimizer` (sgd/momentum/adam), `compatibility_layout` (true = umap-learn 0.5 pipeline, false = 0.6 pipeline), `a`, `b`, `disconnection_distance`, `progress` callback, `gpu` |
| Metrics | euclidean, sqeuclidean, manhattan, chebyshev, minkowski, cosine, correlation, hamming, jaccard, dice, canberra, braycurtis, haversine, hellinger, … (SIMD via `wide`) |
| Precision | `f32` input; R doubles must be converted |
| Parallelism | rayon. NNDescent uses `rayon::current_num_threads()`; some modules build their own pools |
| Determinism | The default SGD is **Hogwild** (lock-free parallel updates), so it is not bit-reproducible with >1 thread. The 0.6 Adam path claims "deterministic hashed negative sampling" (to be verified) |
| GPU | `gpu` feature (wgpu) is optional. **We build without it** |

---

## 2. User-facing interface

### 2.1 The core problem

UMAP's input is an *n × p feature matrix*, but ggplot2 aesthetics map **one column each**
and the stat only sees evaluated aesthetics. Writing `aes(x = ..., y = ...)` makes no sense.

**Solution:** a `features` argument that takes a **tidyselect** expression (like
`dplyr::select()`), resolved against the layer's data. Technically this uses a custom `Layer`
subclass (`layer(layer_class = LayerUmap)`, ggplot2 ≥ 3.5.0). It overrides
`compute_aesthetics()`: it selects the feature columns from the raw layer data and appends them
as hidden columns (`.umap_f1 … .umap_fp`) before the stat runs. *This is the main technical risk
and is the first spike (Phase 0).*

### 2.2 Exported functions

```r
# Stat: the workhorse. Any geom can render the embedding.
stat_umap(
  mapping = NULL, data = NULL, geom = "point", position = "identity", ...,
  features    = where(is.numeric),   # tidyselect
  n_neighbors = 15L,
  min_dist    = 0.1,
  spread      = 1,
  metric      = "euclidean",
  n_epochs    = NULL,                # NULL = upstream default
  init        = "auto",              # auto | spectral | tswspectral | pca | random | recursive
  flavour     = c("0.5", "0.6"),     # compatibility_layout TRUE/FALSE
  scale       = FALSE,               # standardise features first
  scope       = c("layer", "panel"), # one embedding for all facets, or one per facet
  seed        = NA,                  # ggplot2 convention, see 2.4
  n_threads   = umap_threads(),
  control     = umap_control(),      # advanced knobs
  na.rm = FALSE, show.legend = NA, inherit.aes = TRUE
)

# Geom shortcut (ggplot2 convention: geom_density() <-> stat_density())
geom_umap(mapping = NULL, data = NULL, stat = "umap", ..., <same params>)

# Advanced parameters, validated in one place
umap_control(learning_rate = 1, negative_sample_rate = 5L, repulsion_strength = 1,
             local_connectivity = 1, set_op_mix_ratio = 1, a = NULL, b = NULL,
             optimizer = NULL, disconnection_distance = NULL, verbose = FALSE)

# Non-ggplot entry point (also used internally; makes testing and benchmarking easy)
umap_embed(x, ..., n_components = 2L)   # data.frame/matrix -> tibble UMAP1, UMAP2 (+ knn_dist)

# Helpers
umap_threads()   # getOption("ggumap.n_threads", <half the cores>)
theme_umap()     # drops axis ticks and text (UMAP coordinates have no units)
umap_cache_clear()
```

Not exported in v1: `n_components > 2` from the stat (ggplot2 is 2-D; `umap_embed()`
supports it), the GPU path, and `transform()` of new points.

### 2.3 Computed variables (`after_stat()`)

| Variable | Meaning |
|---|---|
| `UMAP1`, `UMAP2` | Embedding coordinates. Default aes: `x = after_stat(UMAP1), y = after_stat(UMAP2)`, which also yields axis labels "UMAP1"/"UMAP2" |
| `knn_dist` | Mean distance to the k nearest neighbours in input space (from `knn_distances`); useful for colouring outliers or density |
| `row` | Original row index |

All non-feature aesthetics (`colour`, `label`, `shape`, …) pass through row-for-row.

### 2.4 Semantics that need care

- **Groups never split the computation.** Mapping `colour = species` must not produce three
  separate UMAPs. Override `compute_layer()` (scope `"layer"`, the default) or `compute_panel()`
  (scope `"panel"`), never `compute_group()`.
- **Facets:** with `scope = "layer"`, facets show subsets of *one* shared embedding (usually what
  people want). `scope = "panel"` gives an independent embedding per panel.
- **Seeds:** follow `position_jitter(seed = NA)`. `NA` draws one seed from R's RNG *at layer
  construction*, so `set.seed()` works and re-rendering or resizing the plot doesn't move the
  points. `NULL` means fresh randomness on each build. An integer is a fixed seed.
- **Reproducibility vs threads:** an integer seed with the default SGD is only bit-reproducible
  when `n_threads = 1`. Document this. If the Phase 0 spike confirms the 0.6/Adam path is
  deterministic across thread counts, recommend `flavour = "0.6"` for reproducible multi-threaded
  output.
- **Caching:** UMAP is expensive and ggplot2 rebuilds plots often (printing, resizing, `ggsave`,
  multiple layers such as `geom_umap() + stat_umap(geom = "text")`). Memoise in a package-level
  environment keyed by `rlang::hash(list(feature_matrix, params, seed))`, with a bounded LRU and
  `umap_cache_clear()`. The cache also makes two layers with the same seed share one layout,
  even under Hogwild.
- **Missing data:** rows with any `NA` or `NaN` in features are dropped, with a warning unless
  `na.rm = TRUE`. `Inf` is an error.
- **Validation (cli errors with clear messages):** non-numeric features (suggest
  `model.matrix()`), zero features, `n < 2`, `n_neighbors >= n` (shrink with a warning),
  unknown metric or init, `init = "pca"` with incompatible options. Validate in R first; map Rust
  `UmapError` to cli errors second.
- **Interrupts and progress:** Ctrl-C during long runs. Check `R_CheckUserInterrupt` from the
  *main* thread only (never from rayon workers), e.g. by driving the optimiser epoch by epoch via
  `UmapSetup`/`UmapOptimizer`, or via the progress callback if it runs on the calling thread.
  With `verbose = TRUE`, show a `cli` progress bar for the four upstream stages.

### 2.5 Example usage (becomes roxygen examples, README, vignette)

```r
library(ggplot2); library(ggumap)

# 1. Simplest: all numeric columns are features
ggplot(penguins, aes(colour = species)) +
  geom_umap(scale = TRUE, na.rm = TRUE)

# 2. Explicit features, tuned, and a second layer sharing the layout
ggplot(penguins, aes(colour = species, label = island)) +
  geom_umap(features = bill_len:body_mass, scale = TRUE, n_neighbors = 30,
            min_dist = 0.3, seed = 1) +
  stat_umap(geom = "text", features = bill_len:body_mass, scale = TRUE,
            n_neighbors = 30, min_dist = 0.3, seed = 1, check_overlap = TRUE) +
  theme_umap()

# 3. Other geoms
ggplot(mnist_sample) + stat_umap(geom = "density_2d_filled", features = starts_with("px"))
ggplot(mnist_sample, aes(colour = after_stat(knn_dist))) + geom_umap(features = starts_with("px"))

# 4. One embedding, faceted
ggplot(penguins, aes(colour = sex)) + geom_umap(scale = TRUE) + facet_wrap(~species)

# 5. Non-Euclidean metric
ggplot(docs, aes(colour = topic)) + geom_umap(features = starts_with("tfidf_"), metric = "cosine")

# 6. Outside ggplot2
emb <- umap_embed(iris, Sepal.Length:Petal.Width, seed = 42)
```

---

## 3. Rust ↔ R integration

- **Binding framework: extendr** (`rextendr`). It's the most widely used option, has
  `rextendr::use_cran_defaults()` and `vendor_pkgs()`, and catches Rust panics as R errors.
  (`savvy` would also work and is leaner. Choose extendr for ecosystem support.)
- `src/rust/Cargo.toml`:
  ```toml
  [dependencies]
  extendr-api = "*"   # pin
  umap      = { git = "https://github.com/apple/embedding-atlas", rev = "a0d0f09…", default-features = false }
  nndescent = { git = "https://github.com/apple/embedding-atlas", rev = "a0d0f09…" }
  ndarray   = "0.17"
  rayon     = "1.11"
  ```
- A thin Rust function `umap_rs(x: &[f64] (column-major), n, p, params: List) -> List`
  converts to a row-major `Array2<f32>`, builds a local `rayon::ThreadPool` with `n_threads`,
  runs `pool.install(|| builder.build())` and returns the embedding plus `knn_distances`.
  All parameter validation is duplicated in R, so Rust errors are a last line of defence.
- **CRAN requirements for Rust** (per CRAN's "Using Rust" policy):
  - `SystemRequirements: Cargo (Rust's package manager), rustc >= <MSRV>`; determine the MSRV
    with `cargo msrv` (upstream tracks `stable`, so the MSRV may be recent).
  - Vendored sources in `src/rust/vendor.tar.xz`, offline build (`--offline`, `CARGO_HOME` in a
    temp dir), at most 2 build jobs, print `rustc --version` in `configure`.
  - **Tarball size:** `cargo vendor` vendors the whole lockfile, including the optional `wgpu`
    tree (274 crates with all features). Use `cargo vendor-filterer` with
    `--features` (none) and `--platform` (Linux/macOS/Windows tiers only) to keep it within
    CRAN's ~5 MB limit. This needs to be measured in Phase 0.
  - `Authors@R` includes `Apple Inc. [cph]`. `inst/AUTHORS` and `LICENSE.note` list all vendored
    crates and their licences (generated by script).
- `tools/update-upstream.R` bumps the pinned `rev`, re-vendors, regenerates the licence notes and
  runs tests. "Latest main" is a moving target, so updates should be deliberate.

---

## 4. Package layout

```
DESCRIPTION  NAMESPACE  LICENSE  LICENSE.note  NEWS.md  README.Rmd  _pkgdown.yml
R/
  stat-umap.R       StatUmap ggproto (setup_params, setup_data, compute_layer/panel)
  geom-umap.R       geom_umap()
  layer-umap.R      LayerUmap subclass: tidyselect of features
  umap-embed.R      umap_embed(): shared engine (validation → cache → Rust)
  umap-control.R    umap_control()
  validate.R        argument checks (rlang/cli style)
  cache.R           memoisation
  theme-umap.R
  extendr-wrappers.R (generated)
  ggumap-package.R  zzz.R
src/  entrypoint.c  Makevars.in  Makevars.win.in  rust/{Cargo.toml, Cargo.lock, src/lib.rs, vendor.tar.xz}
configure  configure.win  tools/
tests/testthat/  (see §5)
vignettes/ggumap.Rmd                     getting started
vignettes/articles/parameters.Rmd        what n_neighbors/min_dist/metric do (galleries)
vignettes/articles/benchmarks.Rmd        precomputed results from bench/
bench/       (.Rbuildignore'd, see §6)
.github/workflows/  R-CMD-check (mac/win/linux × release/devel/oldrel), test-coverage, pkgdown,
                    lint (lintr + air), rust (cargo fmt --check, clippy, cargo test), touchstone
```

Dependencies: Imports `ggplot2 (>= 3.5.0)`, `rlang`, `cli`, `vctrs`, `tidyselect`.
Suggests `testthat (>= 3.0.0)`, `vdiffr`, `withr`, `palmerpenguins` (or base `penguins`, R ≥ 4.5),
`uwot` (cross-checks), `knitr`, `rmarkdown`.

---

## 5. Testing strategy (testthat 3rd edition)

Tests use `n_threads = 1` and fixed seeds by default (CRAN allows at most 2 threads).
`helper-data.R` provides small synthetic Gaussian blobs with known labels.

**Rust level** (`cargo test`): R ↔ ndarray conversion (column-/row-major), parameter parsing,
error mapping.

**R level**, roughly one file per concern:

| File | Covers |
|---|---|
| `test-umap-embed.R` | output shape and names, n_components 2/3, matrix vs data.frame vs tibble input, integer columns, `knn_dist` ≥ 0, row order preserved |
| `test-validation.R` | every invalid parameter → classed error, **snapshot-tested messages** (`expect_snapshot(error = TRUE)`); non-numeric, zero, or Inf features; `n_neighbors >= n` warning; unknown metric/init/flavour |
| `test-features.R` | tidyselect forms (`a:b`, `starts_with()`, `where()`, `-col`, character vector, `all_of()`), default = all numeric, features from layer `data=` vs plot data, mapped aesthetics are not features unless selected |
| `test-stat-umap.R` | `layer_data()` has `x`, `y`, `UMAP1`, `UMAP2`, `knn_dist`; aesthetics stay row-aligned (shuffle rows → labels move with points); **colour grouping does not split the embedding**; `scope = "layer"` vs `"panel"` with facets; `after_stat()` mappings; works with `geom = "text"`, `"label"`, `"density_2d"`, `"hex"` |
| `test-missing.R` | NA rows dropped with warning, `na.rm = TRUE` silent, all-NA → error |
| `test-seed.R` | same integer seed + 1 thread → identical; different seeds → different; `seed = NA` → stable across re-builds, controlled by `set.seed()`; `seed = NULL` → varies; (if confirmed) 0.6/Adam identical across thread counts |
| `test-cache.R` | second build hits the cache (instrumented counter), cache key changes with data/params, `umap_cache_clear()`, multi-layer plots share layout |
| `test-params.R` | every metric and every init runs; `flavour` 0.5/0.6; each `optimizer`; `min_dist` larger → larger mean pairwise distance (monotonic sanity) |
| `test-edge-cases.R` | n = 2, 3, n ≈ n_neighbors, duplicate rows, constant columns, p = 1, very large magnitudes (f32 overflow → error), single-row facet panels |
| `test-quality.R` | *Correctness, not just "it runs":* on 3–5 well-separated blobs, kNN-classifier accuracy in the embedding ≥ 0.95 and trustworthiness (k = 15) ≥ 0.9; iris trustworthiness close to `uwot` (`skip_if_not_installed("uwot")`) |
| `test-visual.R` | `vdiffr::expect_doppelganger()` for a handful of plots (seeded, 1 thread). `skip_on_cran()` because floating-point output may differ across platforms |
| `test-interrupt.R` / manual | interrupt and progress behaviour (partly manual, documented) |

Coverage target ≥ 95 % (covr, R code). `R CMD check --as-cran` must have 0 errors, 0 warnings
and 0 notes on all three OSes, plus rhub `clang-asan`/valgrind runs for the Rust FFI layer.

---

## 6. Benchmark design

Benchmarks live in `bench/` and are excluded from the build. There are two goals: (a) is the Rust
backend fast and good compared with what R users have now, and (b) catch performance regressions
in our own code.

### 6.1 Contenders

| Label | Implementation |
|---|---|
| `ggumap-0.5` | this package, SGD (default) |
| `ggumap-0.6` | this package, recursive init + Adam |
| `uwot` | CRAN standard (C++/RcppAnnoy). Also `nn_method = "nndescent"` (rnndescent) so neighbour search is like-for-like |
| `umap-naive` | `umap::umap(method = "naive")`, i.e. what ggpca uses (skipped above ~20k rows; too slow) |
| `umap-learn` | Python reference via `reticulate` (environment managed with **uv**, `py_require("umap-learn")`) |

Use the same settings everywhere: `n_neighbors = 15`, `min_dist = 0.1`, euclidean, 2-D,
default epochs, spectral init where available, and an equal thread count.

### 6.2 Datasets

- Synthetic Gaussian blobs: n ∈ {1k, 5k, 10k, 50k, 100k, 250k}, p ∈ {10, 50, 300}, for scaling curves.
- Real: iris/penguins (tiny), MNIST 70k × 784 and Fashion-MNIST (downloaded once, cached,
  checksummed), and a scRNA-seq PCA matrix (~50 dims; typical bio use case).

### 6.3 Measurements

- **Wall time**, end-to-end and per stage (kNN / graph / init / optimise, from the upstream
  progress stages). Each contender runs in a fresh `callr` subprocess, so caches and thread pools
  don't leak, with 1 warm-up and ≥ 5 repetitions. Report median and IQR.
- **Peak memory** as max RSS of the subprocess (`ps::ps_memory_info()` sampling or
  `/usr/bin/time -l`). `bench::mark()` alone misses Rust and C++ allocations.
- **Thread scaling** at 1, 2, 4, 8 threads on MNIST.
- **Quality**, on a fixed 5k subsample as upstream's `quality.py` does: trustworthiness (k = 15),
  kNN recall (overlap of input-space and embedding kNN), and kNN-classifier accuracy and
  silhouette on known labels. Over 5 seeds, to show variance as well as means.
- **ggplot2 overhead:** `ggplot_build()` time for `geom_umap()` vs `umap_embed()` +
  `geom_point()`, and cold vs warm cache.

### 6.4 Infrastructure and reporting

- `bench/run.R` (CLI flags: contenders, datasets, sizes) writes tidy results to
  `bench/results/<date>-<machine>.csv` along with machine info (CPU, cores, OS, R, rustc, and
  package versions).
- `vignettes/articles/benchmarks.Rmd` reads the precomputed CSV: log-log time vs n, a memory
  chart, quality dot plots with seed spread, a thread-scaling plot, and side-by-side MNIST
  embeddings of all contenders. The article is never computed on CRAN.
- **Regression CI:** `touchstone` runs a small fixed benchmark (10k × 50 blobs, 1 thread) on each
  PR and comments the timing delta vs `main`.

---

## 7. Phases

0. **Spikes** (de-risking, roughly 1 day)
   - `layer_class` + tidyselect features work through facets and grouping; check behaviour with
     the current ggplot2 4.x (S7) release.
   - A minimal extendr crate compiles the upstream git dep without `gpu`. Measure the vendored
     tarball size with `cargo vendor-filterer`; determine the MSRV.
   - Determinism: same seed across 1, 2, 8 threads for 0.5/SGD and 0.6/Adam.
   - Can we check interrupts (progress callback thread, or epoch-stepping via `UmapOptimizer`)?
1. **Skeleton:** `usethis::create_package`, rextendr scaffolding, CI, lintr/air, licence files.
2. **Engine:** Rust wrapper + `umap_embed()` + validation + cache, with tests.
3. **ggplot2 layer:** `LayerUmap`, `StatUmap`, `stat_umap()`, `geom_umap()`, `theme_umap()`, with tests.
4. **Docs:** roxygen with runnable examples (small n, 1 thread, < 5 s each), README, vignette,
   parameters article, pkgdown site.
5. **Benchmarks:** `bench/`, results, article, touchstone.
6. **Release hardening:** `R CMD check --as-cran` on win-builder, macbuilder and rhub; size
   check; `cran-comments.md`.

---

## 8. Open decisions

1. Package name (`ggumap`?).
2. `scale` default: `FALSE` (matches umap-learn/uwot) or `TRUE` (friendlier for mixed units, as in ggpca)?
3. Default `flavour`: `"0.5"` (faithful to the established algorithm) vs `"0.6"` (newer, possibly
   deterministic and faster)? Decide after benchmarks.
4. CRAN as a target (it drives the vendoring and size work), or GitHub/r-universe only?
5. Default `n_threads`: half the cores (uwot-like) or 1 (safest)?
