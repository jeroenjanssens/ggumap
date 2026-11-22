# Visual regression tests. Floating-point results can differ slightly across
# platforms and compilers, so these only run locally and on CI.
skip_on_cran()
skip_if_not_installed("vdiffr")
skip_if_not(
  identical(Sys.info()[["sysname"]], "Darwin"),
  "snapshots recorded on macOS"
)

test_that("plots look as expected", {
  df <- blobs(n_per = 40, k = 4, p = 8)
  df$id <- as.character(seq_len(nrow(df)))

  vdiffr::expect_doppelganger(
    "geom_umap coloured",
    ggplot2::ggplot(df, ggplot2::aes(colour = label)) + geom_umap(seed = 1)
  )
  vdiffr::expect_doppelganger(
    "theme_umap",
    ggplot2::ggplot(df, ggplot2::aes(colour = label)) +
      geom_umap(seed = 1) +
      theme_umap()
  )
  vdiffr::expect_doppelganger(
    "facets with shared embedding",
    ggplot2::ggplot(df, ggplot2::aes(colour = label)) +
      geom_umap(seed = 1) +
      ggplot2::facet_wrap(ggplot2::vars(label))
  )
  vdiffr::expect_doppelganger(
    "text and points share a layout",
    ggplot2::ggplot(df[1:40, ], ggplot2::aes(label = id)) +
      geom_umap(seed = 1, n_neighbors = 5) +
      stat_umap(
        geom = "text",
        seed = 1,
        n_neighbors = 5,
        vjust = -0.5,
        size = 2
      )
  )
  vdiffr::expect_doppelganger(
    "density of umap_embed",
    ggplot2::ggplot(umap_embed(df, seed = 1), ggplot2::aes(UMAP1, UMAP2)) +
      ggplot2::geom_density_2d_filled()
  )
})
