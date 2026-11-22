test_that("layer data contains the embedding and computed variables", {
  df <- blobs()
  p <- ggplot2::ggplot(df, ggplot2::aes(colour = label)) + geom_umap(seed = 1)
  ld <- layer_data(p)
  expect_equal(nrow(ld), nrow(df))
  expect_true(all(
    c("x", "y", "UMAP1", "UMAP2", "knn_dist", "row") %in% names(ld)
  ))
  expect_equal(ld$x, ld$UMAP1)
  expect_equal(ld$y, ld$UMAP2)
  expect_equal(ld$row, seq_len(nrow(df)))
  expect_false(any(grepl("^\\.umap_f", names(ld))))
})

test_that("the stat matches umap_embed()", {
  df <- blobs()
  p <- ggplot2::ggplot(df) + geom_umap(seed = 4)
  emb <- umap_embed(df, seed = 4)
  expect_equal(layer_data(p)$UMAP1, emb$UMAP1)
  expect_equal(layer_data(p)$knn_dist, emb$knn_dist)
})

test_that("default axis labels name the UMAP dimensions", {
  p <- ggplot2::ggplot(blobs()) + geom_umap()
  labels <- ggplot2::get_labs(p)
  expect_equal(labels$x, "UMAP1", ignore_attr = TRUE)
  expect_equal(labels$y, "UMAP2", ignore_attr = TRUE)
})

test_that("aesthetics stay attached to their rows", {
  df <- blobs(n_per = 30, k = 3)
  df$id <- seq_len(nrow(df))
  shuffled <- df[withr::with_seed(5, sample(nrow(df))), ]
  p <- ggplot2::ggplot(shuffled, ggplot2::aes(colour = label, label = id)) +
    stat_umap(geom = "text", seed = 1)
  ld <- layer_data(p)
  # Points of the same blob must be each other's neighbours in the embedding.
  emb <- cbind(ld$x, ld$y)
  expect_gt(knn_accuracy(emb, shuffled$label), 0.95)
  expect_equal(as.integer(ld$label), shuffled$id)
})

test_that("grouping aesthetics do not split the computation", {
  df <- blobs(n_per = 30, k = 3)
  ungrouped <- layer_data(ggplot2::ggplot(df) + geom_umap(seed = 1))
  grouped <- layer_data(
    ggplot2::ggplot(df, ggplot2::aes(colour = label, shape = label)) +
      geom_umap(seed = 1)
  )
  expect_equal(grouped$x, ungrouped$x)
  expect_equal(grouped$y, ungrouped$y)
  expect_equal(length(unique(grouped$group)), 3)
})

test_that("scope = 'layer' shares one embedding across facets", {
  df <- blobs(n_per = 30, k = 3)
  whole <- layer_data(ggplot2::ggplot(df) + geom_umap(seed = 1))
  faceted <- layer_data(
    ggplot2::ggplot(df) +
      geom_umap(seed = 1) +
      ggplot2::facet_wrap(ggplot2::vars(label))
  )
  expect_equal(length(unique(faceted$PANEL)), 3)
  expect_equal(faceted$x[order(faceted$row)], whole$x)
})

test_that("scope = 'panel' embeds every panel separately", {
  df <- blobs(n_per = 30, k = 3)
  p <- ggplot2::ggplot(df) +
    geom_umap(scope = "panel", seed = 1) +
    ggplot2::facet_wrap(ggplot2::vars(label))
  ld <- layer_data(p)
  expect_equal(nrow(ld), nrow(df))
  panel1 <- ld[ld$PANEL == 1, ]
  emb <- umap_embed(df[df$label == "c1", ], seed = 1)
  expect_equal(panel1$x[order(panel1$row)], emb$UMAP1)
})

test_that("scope = 'panel' skips panels that are too small", {
  df <- blobs(n_per = 30, k = 2)
  df <- rbind(df, df[1:2, ])
  df$panel <- c(rep("a", 60), "b", "b")
  p <- ggplot2::ggplot(df) +
    geom_umap(scope = "panel", seed = 1) +
    ggplot2::facet_wrap(ggplot2::vars(panel))
  expect_warning(ld <- layer_data(p), "at least 3")
  expect_equal(nrow(ld), 60)
})

test_that("explicit position mappings are ignored with a warning", {
  df <- blobs()
  expect_snapshot(
    ld <- layer_data(
      ggplot2::ggplot(df) + geom_umap(ggplot2::aes(x = f1), seed = 1)
    )
  )
  expect_equal(ld$x, ld$UMAP1)
})

test_that("inherited position mappings are ignored silently", {
  df <- blobs()
  p <- ggplot2::ggplot(df, ggplot2::aes(f1, f2)) +
    ggplot2::geom_point() +
    geom_umap(seed = 1)
  expect_silent(ld <- layer_data(p, 2))
  expect_equal(ld$x, ld$UMAP1)
  expect_equal(layer_data(p, 1)$x, df$f1)
})

test_that("computed variables can be mapped", {
  df <- blobs()
  p <- ggplot2::ggplot(df) +
    geom_umap(
      ggplot2::aes(
        x = ggplot2::after_stat(UMAP2),
        y = ggplot2::after_stat(UMAP1),
        colour = ggplot2::after_stat(knn_dist)
      ),
      seed = 1
    )
  ld <- layer_data(p)
  expect_equal(ld$x, ld$UMAP2)
  expect_equal(ld$y, ld$UMAP1)
  expect_type(ld$colour, "character")
})

test_that("missing feature values are removed with a warning", {
  df <- blobs()
  df$f1[1:3] <- NA
  p <- ggplot2::ggplot(df) + geom_umap(seed = 1)
  expect_snapshot(ld <- layer_data(p))
  expect_equal(nrow(ld), nrow(df) - 3)
  expect_equal(ld$row, 4:nrow(df))
  p <- ggplot2::ggplot(df) + geom_umap(seed = 1, na.rm = TRUE)
  expect_silent(layer_data(p))
})

test_that("geoms that draw one mark per observation render the embedding", {
  df <- blobs()
  df$id <- as.character(seq_len(nrow(df)))
  emb <- umap_embed(df, seed = 1)
  geoms <- list(
    stat_umap(geom = "text", ggplot2::aes(label = id), seed = 1),
    stat_umap(geom = "label", ggplot2::aes(label = id), seed = 1),
    stat_umap(geom = "path", seed = 1)
  )
  for (layer in geoms) {
    p <- ggplot2::ggplot(df) + layer
    expect_no_error(ggplot2::ggplotGrob(p))
    # One mark per observation, at the embedded coordinates.
    ld <- layer_data(p)
    expect_equal(nrow(ld), nrow(df))
    expect_equal(ld$x[order(ld$row)], emb$UMAP1)
  }
})

test_that("geoms that need their own statistic are rejected", {
  expect_snapshot(error = TRUE, {
    stat_umap(geom = "density_2d_filled")
    stat_umap(geom = "density2d")
    stat_umap(geom = "hex")
    stat_umap(geom = "smooth")
    stat_umap(geom = ggplot2::GeomContour)
    stat_umap(geom = ggplot2::GeomDensity2dFilled)
  })
  expect_no_error(stat_umap(geom = "text"))
  expect_no_error(stat_umap(geom = ggplot2::GeomLabel))
})

test_that("geom parameters and fixed aesthetics are passed on", {
  p <- ggplot2::ggplot(blobs()) + geom_umap(colour = "red", size = 4, seed = 1)
  ld <- layer_data(p)
  expect_true(all(ld$colour == "red"))
  expect_true(all(ld$size == 4))
})

test_that("positions are applied after the stat", {
  df <- blobs()
  plain <- layer_data(ggplot2::ggplot(df) + geom_umap(seed = 1))
  jittered <- layer_data(
    ggplot2::ggplot(df) +
      geom_umap(position = ggplot2::position_jitter(seed = 1), seed = 1)
  )
  expect_false(isTRUE(all.equal(plain$x, jittered$x)))
  expect_equal(plain$UMAP1, jittered$UMAP1)
})

test_that("empty data gives an empty layer", {
  df <- blobs()[0, ]
  p <- ggplot2::ggplot(df) + geom_umap()
  expect_equal(nrow(layer_data(p)), 0)
})

test_that("stat = 'umap' without the constructor is an error", {
  p <- ggplot2::ggplot(blobs()) + ggplot2::geom_point(stat = StatUmap)
  expect_snapshot(layer_data(p), error = TRUE)
})

test_that("data supplied to the layer is used", {
  df <- blobs()
  p <- ggplot2::ggplot() + geom_umap(data = df, seed = 1)
  expect_equal(nrow(layer_data(p)), nrow(df))
})

test_that("layers can be reused across plots", {
  layer <- geom_umap(seed = 1)
  a <- layer_data(ggplot2::ggplot(blobs(seed = 1)) + layer)
  b <- layer_data(ggplot2::ggplot(blobs(seed = 2)) + layer)
  expect_false(isTRUE(all.equal(a$x, b$x)))
  expect_equal(a$x, layer_data(ggplot2::ggplot(blobs(seed = 1)) + layer)$x)
})

test_that("theme_umap() removes axis decorations", {
  th <- theme_umap()
  expect_s3_class(th$axis.text, "element_blank")
  expect_s3_class(th$axis.ticks, "element_blank")
  expect_s3_class(theme_umap(legend.position = "none"), "theme")
})

test_that("layers copied into every facet panel are embedded once", {
  # A layer without the facet variable is repeated in every panel. Each
  # observation must be embedded once, not once per copy.
  df <- blobs(n_per = 30, k = 3)
  background <- df
  background$label <- NULL
  p <- ggplot2::ggplot(df) +
    geom_umap(data = background, seed = 1) +
    geom_umap(seed = 1) +
    ggplot2::facet_wrap(ggplot2::vars(label))
  copied <- layer_data(p, 1)
  own <- layer_data(p, 2)
  expect_equal(nrow(copied), 3 * nrow(df))
  expect_setequal(copied$row, seq_len(nrow(df)))

  # Every copy of an observation has the same coordinates ...
  coords <- unique(copied[c("row", "x", "y")])
  expect_equal(nrow(coords), nrow(df))
  # ... which match the embedding without facets, and the faceted layer.
  whole <- layer_data(ggplot2::ggplot(df) + geom_umap(seed = 1))
  coords <- coords[order(coords$row), ]
  expect_equal(coords$x, whole$x)
  expect_equal(own$x[order(own$row)], whole$x)
  # The embedding is still faithful (not degenerate from duplicated rows).
  expect_gt(knn_accuracy(cbind(coords$x, coords$y), df$label), 0.95)
})

test_that("missing values in layers copied into panels are dropped from every copy", {
  df <- blobs(n_per = 20, k = 2)
  background <- df
  background$label <- NULL
  background$f1[1] <- NA
  p <- ggplot2::ggplot(df) +
    geom_umap(data = background, seed = 1, na.rm = TRUE) +
    ggplot2::facet_wrap(ggplot2::vars(label))
  ld <- layer_data(p, 1)
  expect_false(1 %in% ld$row)
  expect_equal(nrow(ld), 2 * (nrow(df) - 1))
})

test_that("the row computed variable refers to the layer data", {
  df <- blobs(n_per = 10, k = 2)
  p <- ggplot2::ggplot(df) + geom_umap(seed = 1)
  expect_equal(layer_data(p)$row, seq_len(nrow(df)))
})
