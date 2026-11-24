#' Theme elements for UMAP plots
#'
#' UMAP coordinates have no units and their values carry no meaning, so axis
#' text, ticks and grid lines are mostly noise. `theme_umap()` removes them.
#' Add it to a plot like any other theme modification, after a complete theme
#' such as [ggplot2::theme_minimal()] if you use one.
#'
#' @param ... Further theme elements passed on to [ggplot2::theme()].
#' @return A [ggplot2::theme()] object.
#' @export
#' @examplesIf rlang::is_installed("palmerpenguins")
#' library(ggplot2)
#'
#' ggplot(na.omit(palmerpenguins::penguins), aes(colour = species)) +
#'   geom_umap(scale = TRUE) +
#'   theme_umap()
theme_umap <- function(...) {
  ggplot2::theme(
    axis.text = ggplot2::element_blank(),
    axis.ticks = ggplot2::element_blank(),
    panel.grid.major = ggplot2::element_blank(),
    panel.grid.minor = ggplot2::element_blank(),
    ...
  )
}
