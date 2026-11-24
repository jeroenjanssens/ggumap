# Common development tasks for ggumap. Run `just` to list them.

# List the recipes
default:
    @just --list

# Regenerate the documentation and the Rust wrappers
document:
    NOT_CRAN=true Rscript -e 'devtools::document()'

# Run the R tests (pass a filter, e.g. `just test stat-umap`)
test filter="":
    NOT_CRAN=true Rscript -e 'devtools::test(filter = if (nzchar("{{ filter }}")) "{{ filter }}")'

# Format, lint and test the Rust code
rust:
    cd src/rust && cargo fmt && cargo clippy --all-targets -- -D warnings && cargo test --lib

# Format the R code with air
format:
    air format .

# Lint the R code
lint:
    Rscript -e 'lintr::lint_package()'

# R CMD check as CRAN does it (offline Rust build, at most 2 cores)
check:
    Rscript -e 'devtools::check(remote = TRUE, manual = TRUE, env_vars = c(NOT_CRAN = "", `_R_CHECK_LIMIT_CORES_` = "TRUE"))'

# Re-render README.md from README.Rmd
readme:
    Rscript -e 'devtools::build_readme()'

# Build the pkgdown site in docs/
site:
    NOT_CRAN=true Rscript -e 'pkgdown::build_site(new_process = FALSE, install = TRUE)'

# Rebuild the changed pages of the site and serve it at http://localhost:<port>.
# Re-run after editing. Examples: `just preview`, `just preview 8000`,
# `just preview 4321 true` (rebuild every page)
preview port="4321" full="false":
    NOT_CRAN=true Rscript -e 'pkgdown::build_site(new_process = FALSE, install = TRUE, lazy = !as.logical("{{ full }}"), preview = FALSE)'
    @echo "Serving docs/ at http://localhost:{{ port }} (Ctrl-C to stop)"
    @(sleep 1 && open "http://localhost:{{ port }}" 2>/dev/null || xdg-open "http://localhost:{{ port }}" 2>/dev/null || true) &
    python3 -m http.server {{ port }} --bind 127.0.0.1 --directory docs

# Re-vendor the Rust crates and regenerate inst/AUTHORS
vendor:
    PATH="$HOME/.cargo/bin:$PATH" ./tools/vendor.sh
    Rscript tools/authors.R

# Update the bundled UMAP implementation (default: latest apple/embedding-atlas main)
update-upstream sha="":
    PATH="$HOME/.cargo/bin:$PATH" Rscript tools/update-upstream.R {{ sha }}

# Run the benchmarks (suite: quick or full)
bench suite="quick":
    Rscript bench/run.R --suite={{ suite }}

# Benchmark ggumap against umap and uwot, and redraw the README figure
bench-readme:
    rm -f bench/results/readme.csv
    Rscript bench/run.R --suite=readme --out=bench/results/readme.csv
    Rscript bench/readme-figure.R
    Rscript -e 'rmarkdown::render("README.Rmd", output_format = rmarkdown::github_document(html_preview = FALSE), quiet = TRUE)'
