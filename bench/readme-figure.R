# Draw the benchmark figure for the README from the results of
#
#   Rscript bench/run.R --suite=readme --out=bench/results/readme.csv
#
# Usage: Rscript bench/readme-figure.R [results.csv] [output.png]
library(ggplot2)

args <- commandArgs(trailingOnly = TRUE)
results_file <- if (length(args) >= 1) args[[1]] else "bench/results/readme.csv"
out_file <- if (length(args) >= 2) {
  args[[2]]
} else {
  "man/figures/README-benchmark.png"
}

res <- utils::read.csv(results_file)
res <- res[res$experiment == "datasets", ]
max_threads <- max(res$threads)

label_of <- function(contender, threads) {
  name <- c(`ggumap-0.5` = "ggumap", uwot = "uwot", `umap-naive` = "umap")[
    contender
  ]
  ifelse(
    contender == "umap-naive",
    "umap (pure R)",
    paste0(name, ", ", threads, ifelse(threads == 1, " thread", " threads"))
  )
}
res$series <- label_of(res$contender, res$threads)

# Medians over repetitions.
agg <- stats::aggregate(
  cbind(seconds, trustworthiness) ~ series + contender + threads + n,
  data = res,
  FUN = stats::median
)

# ggumap vs umap; uwot (one line) for reference. Colour follows the
# implementation (categorical slots 1, 3 and 4 of the validated palette, as in
# the benchmark article), line type the number of threads.
series_levels <- c(
  label_of("ggumap-0.5", max_threads),
  label_of("ggumap-0.5", 1),
  label_of("uwot", max_threads),
  label_of("uwot", 1),
  label_of("umap-naive", 1)
)
agg <- agg[agg$series %in% series_levels, ]
agg$series <- factor(agg$series, levels = series_levels)
colours <- stats::setNames(
  c("#2a78d6", "#2a78d6", "#1baf7a", "#1baf7a", "#eda100"),
  series_levels
)
linetypes <- stats::setNames(
  c("solid", "dashed", "solid", "dashed", "solid"),
  series_levels
)

# Headline: speed-up over umap at the largest size both ran.
largest <- max(agg$n[agg$contender == "umap-naive"])
at <- agg[agg$n == largest, ]
speedup <- function(s) {
  at$seconds[at$series == series_levels[5]] / at$seconds[at$series == s]
}
subtitle <- sprintf(
  "At %s points, ggumap is %.0fx faster than umap on %d threads and %.0fx faster on 1 thread.",
  format(largest, big.mark = ","),
  speedup(series_levels[1]),
  max_threads,
  speedup(series_levels[2])
)

p <- ggplot(agg, aes(n, seconds, colour = series, linetype = series)) +
  geom_line(linewidth = 0.8) +
  geom_point(size = 2.4, stroke = 0) +
  scale_x_log10(
    breaks = sort(unique(agg$n)),
    labels = scales::label_number(scale_cut = scales::cut_short_scale()),
    expand = expansion(mult = c(0.03, 0.03))
  ) +
  scale_y_log10(
    breaks = c(0.01, 0.03, 0.1, 0.3, 1, 3, 10, 30, 100, 300),
    labels = function(x) paste0(x, " s")
  ) +
  scale_colour_manual(values = colours, name = NULL) +
  scale_linetype_manual(values = linetypes, name = NULL) +
  labs(
    title = "Time to compute a UMAP embedding",
    subtitle = subtitle,
    x = "Number of observations (Gaussian blobs, 50 dimensions)",
    y = NULL,
    caption = sprintf(
      paste0(
        "Median of %d runs; n_neighbors = 15, min_dist = 0.1, default epochs ",
        "(ggumap and uwot: 500 up to 10,000 points, 200 above; umap: 200).\n",
        "%s, %s. Lower is better."
      ),
      max(res$rep),
      res$cpu[1],
      res$date[1]
    )
  ) +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(linewidth = 0.3, colour = "grey88"),
    plot.title = element_text(face = "bold"),
    plot.title.position = "plot",
    plot.caption = element_text(colour = "grey40", size = 8),
    plot.caption.position = "plot",
    legend.position = "top",
    legend.justification = "left",
    legend.key.width = unit(1.8, "lines"),
    legend.text = element_text(size = 9.5),
    plot.background = element_rect(fill = "white", colour = NA)
  )

ggsave(out_file, p, width = 8, height = 4.6, dpi = 150)
message("Wrote ", out_file)

# Quality at the largest common size, for the table in the README.
q <- agg[agg$n == largest, c("series", "seconds", "trustworthiness")]
q <- q[order(q$series), ]
print(q, row.names = FALSE, digits = 3)
