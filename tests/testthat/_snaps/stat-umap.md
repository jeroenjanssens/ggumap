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

