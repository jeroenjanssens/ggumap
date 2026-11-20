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
