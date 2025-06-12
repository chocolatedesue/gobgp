# Multi-stage build for GoBGP
FROM golang:1.24.4-alpine3.22 AS builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates

# Set working directory
WORKDIR /go/src/github.com/osrg/gobgp

# Copy go mod and sum files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build binaries with same flags as fabric script
RUN CGO_ENABLED=0 go build -ldflags="-s -w -buildid=" -o /go/bin/gobgpd ./cmd/gobgpd
RUN CGO_ENABLED=0 go build -ldflags="-s -w -buildid=" -o /go/bin/gobgp ./cmd/gobgp

# Final stage - use same base image as fabric script
FROM golang:1.24.4-alpine3.22

# Copy binaries from builder stage
COPY --from=builder /go/bin/gobgpd /go/bin/gobgpd
COPY --from=builder /go/bin/gobgp /go/bin/gobgp

# Add to PATH for easier access
ENV PATH="/go/bin:${PATH}"

# Default command
CMD ["/go/bin/gobgpd", "-f", "/etc/gobgp/gobgpd.conf"]