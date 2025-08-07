# Use the official Go image to create a build artifact.
FROM golang:1.22 AS builder

WORKDIR /app

COPY go.mod go.sum ./

RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -o /app/xds-server .

# Start a new stage from scratch for a smaller image
FROM gcr.io/distroless/static-debian11

WORKDIR /

COPY --from=builder /app/xds-server /xds-server

EXPOSE 18000

CMD ["/xds-server"]
