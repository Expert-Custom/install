#!/bin/sh
set -e

TOKEN="$1"
PROJECT="$2"
REGISTRY="npm.pkg.github.com"
CREATE_APP="${EXPERT_CREATE_APP:-@expert-custom/create-app@latest}"

if [ -z "$TOKEN" ] || [ -z "$PROJECT" ]; then
  echo "Uso: curl -fsSL <link> | sh -s -- <token> <pasta-do-projeto>"
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  echo "Node não encontrado. Instale o Node 24 ou mais novo: https://nodejs.org"
  exit 1
fi

NODE_MAJOR=$(node -p "process.versions.node.split('.')[0]")
if [ "$NODE_MAJOR" -lt 24 ]; then
  echo "Node $(node -v) encontrado. O framework precisa do Node 24 ou mais novo."
  exit 1
fi

NPMRC="$HOME/.npmrc"
touch "$NPMRC"
grep -v "@expert-custom:registry=" "$NPMRC" | grep -v "//$REGISTRY/:_authToken=" > "$NPMRC.tmp" || true
echo "@expert-custom:registry=https://$REGISTRY" >> "$NPMRC.tmp"
echo "//$REGISTRY/:_authToken=$TOKEN" >> "$NPMRC.tmp"
mv "$NPMRC.tmp" "$NPMRC"
chmod 600 "$NPMRC"
echo "Acesso aos pacotes da ExpertCustom configurado."

npm exec --yes --package="$CREATE_APP" -- create-app "$PROJECT" < /dev/tty
