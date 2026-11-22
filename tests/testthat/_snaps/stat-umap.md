# explicit position mappings are ignored with a warning

    Code
      ld <- layer_data(ggplot2::ggplot(df) + geom_umap(ggplot2::aes(x = f1), seed = 1))
    Condition
      Warning:
      Ignoring the x aesthetic of `stat_umap()`.
      i Positions come from the embedding; use `after_stat(UMAP1)` or `after_stat(UMAP2)` to map them explicitly.

# missing feature values are removed with a warning

    Code
      ld <- layer_data(p)
    Condition
      Warning:
      Removed 3 rows containing missing feature values (`stat_umap()`).

# geoms that need their own statistic are rejected

    Code
      stat_umap(geom = "density_2d_filled")
    Condition
      Error in `stat_umap()`:
      ! `geom = "density_2d_filled"` needs its own statistic, which can't be combined with `stat_umap()`.
      i Compute the embedding with `umap_embed()` and plot the result with the regular geom, e.g. `ggplot(umap_embed(data), aes(UMAP1, UMAP2)) + geom_density_2d_filled()`.
    Code
      stat_umap(geom = "density2d")
    Condition
      Error in `stat_umap()`:
      ! `geom = "density2d"` needs its own statistic, which can't be combined with `stat_umap()`.
      i Compute the embedding with `umap_embed()` and plot the result with the regular geom, e.g. `ggplot(umap_embed(data), aes(UMAP1, UMAP2)) + geom_density2d()`.
    Code
      stat_umap(geom = "hex")
    Condition
      Error in `stat_umap()`:
      ! `geom = "hex"` needs its own statistic, which can't be combined with `stat_umap()`.
      i Compute the embedding with `umap_embed()` and plot the result with the regular geom, e.g. `ggplot(umap_embed(data), aes(UMAP1, UMAP2)) + geom_hex()`.
    Code
      stat_umap(geom = "smooth")
    Condition
      Error in `stat_umap()`:
      ! `geom = "smooth"` needs its own statistic, which can't be combined with `stat_umap()`.
      i Compute the embedding with `umap_embed()` and plot the result with the regular geom, e.g. `ggplot(umap_embed(data), aes(UMAP1, UMAP2)) + geom_smooth()`.
    Code
      stat_umap(geom = ggplot2::GeomContour)
    Condition
      Error in `stat_umap()`:
      ! `geom = "contour"` needs its own statistic, which can't be combined with `stat_umap()`.
      i Compute the embedding with `umap_embed()` and plot the result with the regular geom, e.g. `ggplot(umap_embed(data), aes(UMAP1, UMAP2)) + geom_contour()`.
    Code
      stat_umap(geom = ggplot2::GeomDensity2dFilled)
    Condition
      Error in `stat_umap()`:
      ! `geom = "density_2d_filled"` needs its own statistic, which can't be combined with `stat_umap()`.
      i Compute the embedding with `umap_embed()` and plot the result with the regular geom, e.g. `ggplot(umap_embed(data), aes(UMAP1, UMAP2)) + geom_density_2d_filled()`.

# stat = 'umap' without the constructor is an error

    Code
      layer_data(p)
    Condition
      Error in `ggplot2::geom_point()`:
      ! Problem while computing stat.
      i Error occurred in the 1st layer.
      Caused by error:
      ! `stat_umap()` could not find any feature columns.
      i Use `stat_umap()` or `geom_umap()` rather than `stat = "umap"`.

