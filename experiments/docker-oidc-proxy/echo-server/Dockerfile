FROM golang:1.24 AS builder

WORKDIR /app
COPY . .
RUN go build -o echo-server main.go

EXPOSE 5678
ENTRYPOINT ["/app/echo-server"]