# Single-threaded, silent and cache-free by default: deterministic and within
# CRAN's limit of two cores. Tests that need other settings set them locally.
withr::local_options(
  list(ggumap.n_threads = 1L, ggumap.progress = FALSE, ggumap.cache_size = 0L),
  .local_envir = teardown_env()
)
