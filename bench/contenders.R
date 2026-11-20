# Each contender is a function(x, threads, seed) returning an n x 2 matrix.
# They are evaluated inside a fresh R process (see run.R).

contenders <- list(
  `ggumap-0.5` = list(
    max_n = Inf,
    setup = function() library(ggumap),
    run = function(x, threads, seed) {
      as.matrix(ggumap::umap_embed(
        x,
        flavour = "0.5",
        seed = seed,
        n_threads = threads,
        control = ggumap::umap_control(progress = FALSE)
      )[1:2])
    }
  ),
  `ggumap-0.6` = list(
    max_n = Inf,
    setup = function() library(ggumap),
    run = function(x, threads, seed) {
      as.matrix(ggumap::umap_embed(
        x,
        flavour = "0.6",
        seed = seed,
        n_threads = threads,
        control = ggumap::umap_control(progress = FALSE)
      )[1:2])
    }
  ),
  uwot = list(
    max_n = Inf,
    setup = function() library(uwot),
    run = function(x, threads, seed) {
      set.seed(seed)
      uwot::umap(
        x,
        n_neighbors = 15,
        min_dist = 0.1,
        n_threads = threads,
        n_sgd_threads = threads
      )
    }
  ),
  `umap-naive` = list(
    max_n = 10000,
    setup = function() library(umap),
    run = function(x, threads, seed) {
      cfg <- umap::umap.defaults
      cfg$random_state <- seed
      umap::umap(x, config = cfg, method = "naive")$layout
    }
  ),
  `umap-learn-0.5` = list(
    max_n = Inf,
    setup = function() {
      reticulate::py_require(c("umap-learn==0.5.*", "numpy"))
      invisible(reticulate::import("umap"))
    },
    run = function(x, threads, seed) {
      umap <- reticulate::import("umap")
      # n_jobs is ignored when random_state is set, so leave the seed unset
      # to allow parallelism, as most users would.
      model <- umap$UMAP(
        n_neighbors = 15L,
        min_dist = 0.1,
        n_jobs = as.integer(threads)
      )
      model$fit_transform(x)
    }
  ),
  `umap-learn-0.6` = list(
    max_n = Inf,
    setup = function() {
      reticulate::py_require(c("umap-learn==0.6.*", "numpy"))
      invisible(reticulate::import("umap"))
    },
    run = function(x, threads, seed) {
      umap <- reticulate::import("umap")
      model <- umap$UMAP(
        n_neighbors = 15L,
        min_dist = 0.1,
        n_jobs = as.integer(threads)
      )
      model$fit_transform(x)
    }
  )
)

contender_versions <- function(name) {
  switch(
    name,
    `ggumap-0.5` = ,
    `ggumap-0.6` = as.character(utils::packageVersion("ggumap")),
    uwot = as.character(utils::packageVersion("uwot")),
    `umap-naive` = as.character(utils::packageVersion("umap")),
    `umap-learn-0.5` = ,
    `umap-learn-0.6` = reticulate::import("umap")$`__version__`
  )
}
