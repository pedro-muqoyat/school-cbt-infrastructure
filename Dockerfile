# ==========================================
# STAGE 1: Ekstraktor Sertifikat dan Waktu
# ==========================================
FROM debian:bullseye-slim AS builder
RUN apt-get update && apt-get install -y ca-certificates tzdata && rm -rf /var/lib/apt/lists/*

# ==========================================
# STAGE 2: Image Distroless
# ==========================================
FROM gcr.io/distroless/base-debian11

WORKDIR /app

COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
ENV TZ=Asia/Jakarta

COPY main-amd64 .

USER nonroot:nonroot

EXPOSE 9988

CMD ["./main-amd64"]
