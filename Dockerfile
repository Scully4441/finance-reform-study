# Reproducibility container (design document, Section 11).
# R version pinned to the one recorded in outputs/package_versions.csv (4.6.1);
# packages restored from renv.lock.
FROM rocker/r-ver:4.6.1
RUN apt-get update && apt-get install -y --no-install-recommends \
    git libcurl4-openssl-dev libssl-dev libxml2-dev \
    libglpk-dev libgmp-dev cmake curl xz-utils \
    && rm -rf /var/lib/apt/lists/*
# clarabel (CVXR -> HonestDiD) builds with Rust >= 1.78; Ubuntu's rustc is older
RUN curl -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain 1.85.0
ENV PATH=/root/.cargo/bin:$PATH
WORKDIR /study
ENV RENV_PATHS_LIBRARY=/study/renv/library
COPY renv.lock renv.lock
COPY .Rprofile .Rprofile
COPY renv/activate.R renv/activate.R
COPY renv/settings.json renv/settings.json
RUN Rscript -e "renv::restore(prompt = FALSE)"
COPY . .
CMD ["Rscript", "R/10_run_all.R"]
