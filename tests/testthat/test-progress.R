test_that("progress callbacks are called on the main thread", {
  df <- blobs()
  params <- rust_params(
    check_umap_args(
      15L,
      2L,
      0.1,
      1,
      "euclidean",
      NULL,
      "auto",
      "0.5",
      FALSE,
      1,
      1L,
      umap_control()
    ),
    seed = 1
  )
  stages <- character()
  fractions <- numeric()
  res <- umap_rs(
    as.matrix(df[1:8]),
    params,
    function(fraction, stage) {
      stages <<- c(stages, stage)
      fractions <<- c(fractions, fraction)
    },
    FALSE
  )
  expect_type(res, "list")
  expect_true("Optimizing layout" %in% stages)
  expect_true(all(fractions >= 0 & fractions <= 1))
})

test_that("errors in the progress callback stop the computation", {
  df <- blobs()
  params <- rust_params(
    check_umap_args(
      15L,
      2L,
      0.1,
      1,
      "euclidean",
      NULL,
      "auto",
      "0.5",
      FALSE,
      1,
      1L,
      umap_control()
    ),
    seed = 1
  )
  # R_tryEval prints the callback's error before returning it; keep it out
  # of the test output.
  expect_error(utils::capture.output(
    umap_rs(as.matrix(df[1:8]), params, function(...) stop("boom"), FALSE),
    type = "message"
  ))
  # The worker thread was stopped and joined: new computations still work.
  expect_type(umap_rs(as.matrix(df[1:8]), params, NULL, FALSE), "list")
})

test_that("a progress bar does not break the computation", {
  withr::local_options(cli.progress_show_after = 0, cli.dynamic = FALSE)
  df <- blobs()
  expect_no_error(
    utils::capture.output(
      emb <- umap_embed(df, seed = 1, control = umap_control(progress = TRUE)),
      type = "message"
    )
  )
  expect_true(all(is.finite(emb$UMAP1)))
})

test_that("Rust errors are reported as R errors", {
  df <- blobs()
  params <- rust_params(
    check_umap_args(
      15L,
      2L,
      0.1,
      1,
      "euclidean",
      NULL,
      "auto",
      "0.5",
      FALSE,
      1,
      1L,
      umap_control()
    ),
    seed = 1
  )
  params$metric <- "not-a-metric"
  expect_error(
    run_umap(as.matrix(df[1:8]), params, progress = FALSE),
    class = "ggumap_error_rust"
  )
  params$metric <- "euclidean"
  params$init <- "nope"
  expect_error(umap_rs(as.matrix(df[1:8]), params, NULL, FALSE), "unknown init")
})

test_that("mean_knn_dist() excludes the point itself", {
  idx <- rbind(c(1L, 2L, 3L), c(2L, 1L, NA))
  dist <- rbind(c(0, 1, 3), c(0, 1, 9))
  expect_equal(mean_knn_dist(idx, dist), c(2, 1))
})
