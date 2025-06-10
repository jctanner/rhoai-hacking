FROM alpine:3.20

RUN apk add --no-cache curl ca-certificates

# Copy oauth2-proxy binary from official image
COPY --from=quay.io/oauth2-proxy/oauth2-proxy:latest /bin/oauth2-proxy /bin/oauth2-proxy

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]