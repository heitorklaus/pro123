# ==============================================================================
# Multi-stage Build para o Microserviço Dart Mavis PDF (Ultra Rápido & Leve)
# ==============================================================================

# Estágio 1: Compilação nativa AOT
FROM dart:stable AS build

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart pub get --offline
RUN dart compile exe bin/server.dart -o bin/server

# Estágio 2: Runtime ultra-enxuto para o Easypanel
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/

ENV PORT=8080
EXPOSE 8080

CMD ["/app/bin/server"]
