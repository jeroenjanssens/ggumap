test_that("long computations can be interrupted", {
  skip_on_cran()
  skip_on_os("windows") # SIGINT semantics differ
  skip_if_not_installed("callr")

  proc <- callr::r_bg(
    function() {
      options(ggumap.progress = FALSE)
      x <- matrix(stats::rnorm(60000 * 50), ncol = 50)
      out <- tryCatch(
        {
          ggumap::umap_embed(x, seed = 1, n_threads = 1)
          "finished"
        },
        interrupt = function(e) "interrupted"
      )
      # R must still be usable after the interrupt.
      paste(out, 1 + 1)
    },
    package = TRUE
  )
  on.exit(proc$kill(), add = TRUE)
  # Let the computation start, then press Ctrl-C.
  Sys.sleep(6)
  expect_true(proc$is_alive())
  proc$interrupt()
  start <- Sys.time()
  proc$wait(timeout = 60000)
  elapsed <- as.numeric(Sys.time() - start, units = "secs")
  expect_false(proc$is_alive())
  expect_equal(proc$get_result(), "interrupted 2")
  expect_lt(elapsed, 30)
})
