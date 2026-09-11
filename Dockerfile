# Reproducibility container (design document, Section 11).
# Pin the R version to the one recorded in outputs/package_versions.csv before
# the freeze, then replace the install step with renv::restore().
FROM rocker/r-ver:4.5.1
RUN apt-get update && apt-get install -y --no-install-recommends \
    git libcurl4-openssl-dev libssl-dev libxml2-dev \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /study
COPY R/00_install_packages.R R/00_install_packages.R
RUN Rscript R/00_install_packages.R
COPY . .
CMD ["Rscript", "R/10_run_all.R"]
