# ── ESTÁGIO 1: COMPILAÇÃO DO FLUTTER WEB ──
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Copia os arquivos do projeto
COPY . .

# Obtém as dependências e compila para Web em modo Release
RUN flutter pub get
RUN flutter build web --release

# ── ESTÁGIO 2: SERVIDOR WEB NGINX ULTRA-LEVE ──
FROM nginx:alpine

# Copia o bundle compilado do Flutter Web para o Nginx
COPY --from=build /app/build/web /usr/share/nginx/html

# Configuração Nginx com suporte a SPA (Single Page Application) e Gzip
RUN cat <<'EOF' > /etc/nginx/conf.d/default.conf
server {
    listen 80;
    server_name localhost;

    location / {
        root /usr/share/nginx/html;
        index index.html index.htm;
        try_files $uri $uri/ /index.html;
    }

    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
}
EOF

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
