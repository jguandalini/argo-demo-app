#!/usr/bin/env bash
# Gera as imagens 1.0 e 1.1 e envia para o Docker Hub.
#
# Uso:
#   docker login
#   ./scripts/build-push.sh SEU_USUARIO_DOCKERHUB
#
# Por padrão gera a imagem para a arquitetura da sua máquina (ex.: amd64),
# só com "docker build" + "docker push". Não precisa de buildx.
#
# Opcional, multi-arquitetura (amd64 + arm64, para quem usa Mac Apple Silicon):
#   MULTIARCH=1 ./scripts/build-push.sh SEU_USUARIO_DOCKERHUB
#   (precisa do plugin buildx e do emulador QEMU, veja o README)
set -euo pipefail

USUARIO="${1:?Informe o usuário do Docker Hub. Ex: ./scripts/build-push.sh joao}"
IMAGEM="${USUARIO}/demo-app"
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
MULTIARCH="${MULTIARCH:-0}"

if [ "$MULTIARCH" = "1" ]; then
  if ! docker buildx version >/dev/null 2>&1; then
    echo "ERRO: o plugin 'docker buildx' não está instalado."
    echo "  Ubuntu (pacote docker.io):     sudo apt install docker-buildx"
    echo "  Docker CE (repositório docker): sudo apt install docker-buildx-plugin"
    echo "Ou rode sem MULTIARCH=1 para gerar só para a sua arquitetura."
    exit 1
  fi
  docker buildx inspect demo-builder >/dev/null 2>&1 || docker buildx create --name demo-builder
  docker buildx use demo-builder
fi

for VERSAO in 1.0 1.1; do
  echo ">>> Gerando ${IMAGEM}:${VERSAO}"
  if [ "$MULTIARCH" = "1" ]; then
    docker buildx build \
      --platform linux/amd64,linux/arm64 \
      --build-arg APP_VERSION="${VERSAO}" \
      -t "${IMAGEM}:${VERSAO}" \
      --push \
      "${RAIZ}/app"
  else
    docker build --build-arg APP_VERSION="${VERSAO}" -t "${IMAGEM}:${VERSAO}" "${RAIZ}/app"
    docker push "${IMAGEM}:${VERSAO}"
  fi
done

echo
echo "Pronto! Imagens publicadas:"
echo "  https://hub.docker.com/r/${IMAGEM}/tags"
