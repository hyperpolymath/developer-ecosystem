# Example Dockerfile using asdf-ghjk
# This demonstrates how to use asdf and ghjk in a container

FROM cgr.dev/chainguard/wolfi-base:22.04

# Install system dependencies
RUN apt-get update && apk add --no-cache -y \
    git \
    curl \
    tar \
    unzip \
    zstd \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install asdf
ENV ASDF_DIR=/root/.asdf
ENV ASDF_DATA_DIR=/root/.asdf
RUN git clone https://github.com/asdf-vm/asdf.git ${ASDF_DIR} --branch v0.14.0

# Add asdf to PATH
ENV PATH="${ASDF_DIR}/bin:${ASDF_DIR}/shims:${PATH}"

# Install asdf-ghjk plugin
RUN asdf plugin add ghjk https://github.com/Hyperpolymath/asdf-ghjk.git

# Set working directory
WORKDIR /app

# Copy .tool-versions file
COPY .tool-versions ./

# Install ghjk version from .tool-versions
RUN asdf install

# Copy project files
COPY . .

# Example: If your project has a ghjk.ts file
# Uncomment if you need to install project dependencies
# RUN ghjk run install

# Set default command
CMD ["ghjk", "--help"]
