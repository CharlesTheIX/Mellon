# Build stage
FROM ubuntu:22.04 AS builder

# Install Zig
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN curl -L https://ziglang.org/download/0.15.2/zig-linux-x86_64-0.15.2.tar.xz | tar -xJ -C /usr/local/bin --strip-components=1

# Copy project files
WORKDIR /build
COPY build.zig build.zig.zon ./
COPY src ./src
COPY docs ./docs

# Build the project
RUN zig build -Doptimize=ReleaseSafe

# Runtime stage
FROM ubuntu:22.04

# Install minimal runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy the built binary from builder stage
COPY --from=builder /build/zig-out/bin/mellon /usr/local/bin/mellon

# Copy docs for help and intro commands
COPY --from=builder /build/docs /docs

# Add binary to PATH
ENV PATH="/usr/local/bin:${PATH}"

# Set working directory
WORKDIR /root

# Make binary executable
RUN chmod +x /usr/local/bin/mellon

# Set the entry point to run mellon
ENTRYPOINT ["mellon"]
