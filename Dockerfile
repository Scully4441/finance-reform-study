FROM rocker/r-ver:4.6.1
RUN apt-get update && apt-get install -y --no-install-recommends \
    git libcurl4-openssl-dev libssl-dev libxml2-dev \
    libglpk-dev libgmp-dev cmake curl xz-utils mdbtools unzip \
    && rm -rf /var/lib/apt/lists/*
RUN curl -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain 1.85.0
ENV PATH=/root/.cargo/bin:$PATH
WORKDIR /study
ENV RENV_PATHS_LIBRARY=/opt/renv/library
COPY renv.lock renv.lock
COPY .Rprofile .Rprofile
COPY renv/activate.R renv/activate.R
COPY renv/settings.json renv/settings.json
RUN Rscript -e "renv::restore(prompt = FALSE)"
COPY . .
CMD ["Rscript", "R/13_run_all.R"]
