# Reproducibility container (design document, Section 11).
# R version pinned to the one recorded in outputs/package_versions.csv (4.6.1);
# packages restored from renv.lock. The image holds code and the lockfile only;
# data/raw, data/derived and outputs are excluded (.dockerignore) and the
# repository folder is mounted as /study at run time (README, How to reproduce).
FROM rocker/r-ver:4.6.1
RUN apt-get update && apt-get install -y --no-install-recommends \
    git libcurl4-openssl-dev libssl-dev libxml2-dev \
    libglpk-dev libgmp-dev cmake curl xz-utils \
    && rm -rf /var/lib/apt/lists/*
# clarabel (CVXR -> HonestDiD) builds with Rust >= 1.78; Ubuntu's rustc is older
RUN curl -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain 1.85.0
ENV PATH=/root/.cargo/bin:$PATH
WORKDIR /study
# library outside /study, so the mounted repository does not hide it
ENV RENV_PATHS_LIBRARY=/opt/renv/library
COPY renv.lock renv.lock
COPY .Rprofile .Rprofile
COPY renv/activate.R renv/activate.R
COPY renv/settings.json renv/settings.json
RUN Rscript -e "renv::restore(prompt = FALSE)"
COPY . .
CMD ["Rscript", "R/10_run_all.R"]
