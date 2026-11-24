# Benchmark datasets. Each function returns list(x = <double matrix>, labels).

bench_blobs <- function(n, p = 50, k = 10, seed = 1) {
  withr::with_seed(seed, {
    centres <- matrix(stats::rnorm(k * p, sd = 4), k, p)
    labels <- sample.int(k, n, replace = TRUE)
    x <- centres[labels, , drop = FALSE] + matrix(stats::rnorm(n * p), n, p)
  })
  list(x = x, labels = labels)
}

bench_penguins <- function() {
  df <- stats::na.omit(palmerpenguins::penguins)
  x <- scale(as.matrix(df[c(
    "bill_length_mm",
    "bill_depth_mm",
    "flipper_length_mm",
    "body_mass_g"
  )]))
  list(x = unname(x), labels = as.integer(df$species))
}

# MNIST (70,000 x 784), downloaded once and cached in bench/data.
bench_mnist <- function(n = NULL, cache = file.path("bench", "data")) {
  dir.create(cache, showWarnings = FALSE, recursive = TRUE)
  rds <- file.path(cache, "mnist.rds")
  if (!file.exists(rds)) {
    base <- "https://storage.googleapis.com/cvdf-datasets/mnist/"
    files <- c(
      "train-images-idx3-ubyte.gz",
      "train-labels-idx1-ubyte.gz",
      "t10k-images-idx3-ubyte.gz",
      "t10k-labels-idx1-ubyte.gz"
    )
    for (f in files) {
      dest <- file.path(cache, f)
      if (!file.exists(dest)) {
        utils::download.file(paste0(base, f), dest, mode = "wb")
      }
    }
    read_images <- function(path) {
      con <- gzfile(path, "rb")
      on.exit(close(con))
      header <- readBin(con, "integer", n = 4, size = 4, endian = "big")
      stopifnot(header[1] == 2051L)
      px <- readBin(
        con,
        "integer",
        n = header[2] * header[3] * header[4],
        size = 1,
        signed = FALSE
      )
      matrix(as.double(px), nrow = header[2], byrow = TRUE)
    }
    read_labels <- function(path) {
      con <- gzfile(path, "rb")
      on.exit(close(con))
      header <- readBin(con, "integer", n = 2, size = 4, endian = "big")
      stopifnot(header[1] == 2049L)
      readBin(con, "integer", n = header[2], size = 1, signed = FALSE)
    }
    x <- rbind(
      read_images(file.path(cache, files[1])),
      read_images(file.path(cache, files[3]))
    )
    labels <- c(
      read_labels(file.path(cache, files[2])),
      read_labels(file.path(cache, files[4]))
    )
    stopifnot(nrow(x) == 70000, ncol(x) == 784, length(labels) == 70000)
    saveRDS(list(x = x / 255, labels = labels), rds)
  }
  data <- readRDS(rds)
  if (!is.null(n) && n < nrow(data$x)) {
    idx <- withr::with_seed(1, sort(sample.int(nrow(data$x), n)))
    data <- list(x = data$x[idx, ], labels = data$labels[idx])
  }
  data
}
