# Containerfile
FROM node:20-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Install Nickel and Just
RUN curl -L https://github.com/casey/just/releases/download/1.13.0/just-1.13.0-x86_64-unknown-linux-musl.tar.gz | tar -xz -C /usr/local/bin
RUN curl -L https://github.com/tweag/nickel/releases/download/1.2.1/nickel-x86_64-linux -o /usr/local/bin/nickel && chmod +x /usr/local/bin/nickel

WORKDIR /app
COPY . .

RUN npm install -g rescript
RUN just strike

CMD ["just", "bundle"]
