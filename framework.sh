#!/bin/sh
set -e

TOKEN="$1"
PROJECT="$2"
REGISTRY="npm.pkg.github.com"
CREATE_APP="${EXPERT_CREATE_APP:-@expert-custom/create-app@latest}"
NPMRC="$HOME/.npmrc"

if ! command -v node >/dev/null 2>&1; then
  echo "Node não encontrado. Instale o Node 24 ou mais novo: https://nodejs.org"
  exit 1
fi

NODE_MAJOR=$(node -p "process.versions.node.split('.')[0]")
if [ "$NODE_MAJOR" -lt 24 ]; then
  echo "Node $(node -v) encontrado. O framework precisa do Node 24 ou mais novo."
  exit 1
fi

HAS_TOKEN=no
if [ -f "$NPMRC" ] && grep -q "//$REGISTRY/:_authToken=" "$NPMRC"; then
  HAS_TOKEN=yes
fi

if [ -z "$TOKEN" ] && [ "$HAS_TOKEN" = no ]; then
  printf "Token de acesso da ExpertCustom: "
  stty -echo < /dev/tty
  read -r TOKEN < /dev/tty
  stty echo < /dev/tty
  echo
  if [ -z "$TOKEN" ]; then
    echo "Sem o token não dá para baixar o framework."
    exit 1
  fi
fi

if [ -n "$TOKEN" ]; then
  touch "$NPMRC"
  grep -v "@expert-custom:registry=" "$NPMRC" | grep -v "//$REGISTRY/:_authToken=" > "$NPMRC.tmp" || true
  echo "@expert-custom:registry=https://$REGISTRY" >> "$NPMRC.tmp"
  echo "//$REGISTRY/:_authToken=$TOKEN" >> "$NPMRC.tmp"
  mv "$NPMRC.tmp" "$NPMRC"
  chmod 600 "$NPMRC"
  echo "Acesso aos pacotes da ExpertCustom configurado."
fi

if [ -z "$PROJECT" ]; then
  printf "Nome da pasta do projeto: "
  read -r PROJECT < /dev/tty
  if [ -z "$PROJECT" ]; then
    echo "Informe o nome da pasta."
    exit 1
  fi
fi

npm exec --yes --package="$CREATE_APP" -- create-app "$PROJECT" < /dev/tty
