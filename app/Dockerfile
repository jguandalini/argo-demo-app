# Imagem da aplicação de demonstração (Nginx servindo uma página estática)
#
# Build:
#   docker build --build-arg APP_VERSION=1.0 -t SEU_USUARIO/demo-app:1.0 app/
#   docker build --build-arg APP_VERSION=1.1 -t SEU_USUARIO/demo-app:1.1 app/

FROM nginx:1.28-alpine

# Qual pasta de página usar: v1.0 ou v1.1
ARG APP_VERSION=1.0

LABEL org.opencontainers.image.title="demo-app" \
      org.opencontainers.image.description="App de demonstração para Kubernetes + Argo CD" \
      org.opencontainers.image.version="${APP_VERSION}"

# Configuração do Nginx (página, /version e /healthz)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Página da versão escolhida
COPY v${APP_VERSION}/ /usr/share/nginx/html/

# Grava a versão no endpoint /version
RUN sed -i "s/__APP_VERSION__/${APP_VERSION}/g" /etc/nginx/conf.d/default.conf

EXPOSE 80
