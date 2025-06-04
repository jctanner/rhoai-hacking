FROM golang:1.24-alpine as builder
WORKDIR /app
COPY redirect-handler.go .
RUN go build -o redirect-handler redirect-handler.go

FROM alpine
COPY --from=builder /app/redirect-handler /usr/local/bin/redirect-handler
EXPOSE 4181
ENTRYPOINT ["/usr/local/bin/redirect-handler"]
