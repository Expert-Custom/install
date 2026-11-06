#!/bin/sh
set -e

# Instalador do framework ExpertCustom. Cria um projeto novo em TypeScript ou em Java.
#   curl ... | sh                # pergunta tudo
#   curl ... | sh -s -- --java   # já escolhe Java

LANGUAGE=""
PROJECT=""
for arg in "$@"; do
  case "$arg" in
    --ts|--typescript) LANGUAGE="ts" ;;
    --java) LANGUAGE="java" ;;
    --*) ;;
    *) [ -z "$PROJECT" ] && PROJECT="$arg" ;;
  esac
done

NPM_REGISTRY="npm.pkg.github.com"
MAVEN_URL="https://maven.pkg.github.com/Expert-Custom/framework-java"
CREATE_APP="${EXPERT_CREATE_APP:-@expert-custom/create-app@latest}"

ask() {
  printf "%s" "$1" >&2
  read -r REPLY < /dev/tty
  echo "$REPLY"
}

ask_hidden() {
  printf "%s" "$1" >&2
  stty -echo < /dev/tty
  read -r REPLY < /dev/tty
  stty echo < /dev/tty
  echo >&2
  echo "$REPLY"
}

if [ -z "$LANGUAGE" ]; then
  echo "Em que linguagem é o projeto?"
  echo "  1) TypeScript (padrão)"
  echo "  2) Java"
  case "$(ask 'Digite o número [1]: ')" in
    2) LANGUAGE="java" ;;
    *) LANGUAGE="ts" ;;
  esac
fi

# ---- acesso aos pacotes privados (o mesmo token do GitHub serve para npm e Maven) --------

configure_npm() {
  NPMRC="$HOME/.npmrc"
  if [ -f "$NPMRC" ] && grep -q "//$NPM_REGISTRY/:_authToken=" "$NPMRC"; then
    return
  fi
  [ -z "$TOKEN" ] && TOKEN=$(ask_hidden "Token de acesso da ExpertCustom: ")
  if [ -z "$TOKEN" ]; then echo "Sem o token não dá para baixar o framework." >&2; exit 1; fi
  touch "$NPMRC"
  grep -v "@expert-custom:registry=" "$NPMRC" | grep -v "//$NPM_REGISTRY/:_authToken=" > "$NPMRC.tmp" || true
  echo "@expert-custom:registry=https://$NPM_REGISTRY" >> "$NPMRC.tmp"
  echo "//$NPM_REGISTRY/:_authToken=$TOKEN" >> "$NPMRC.tmp"
  mv "$NPMRC.tmp" "$NPMRC"
  chmod 600 "$NPMRC"
  echo "Acesso aos pacotes npm da ExpertCustom configurado."
}

configure_maven() {
  SETTINGS="$HOME/.m2/settings.xml"
  if [ -f "$SETTINGS" ] && grep -q "<id>expertcustom</id>" "$SETTINGS"; then
    return
  fi
  USERNAME=$(ask "Usuário do GitHub: ")
  [ -z "$TOKEN" ] && TOKEN=$(ask_hidden "Token de acesso da ExpertCustom: ")
  if [ -z "$USERNAME" ] || [ -z "$TOKEN" ]; then echo "Sem usuário e token não dá para baixar o framework." >&2; exit 1; fi
  mkdir -p "$HOME/.m2"
  SERVER="    <server>\n      <id>expertcustom</id>\n      <username>$USERNAME</username>\n      <password>$TOKEN</password>\n    </server>"
  if [ ! -f "$SETTINGS" ]; then
    printf '<settings>\n  <servers>\n%b\n  </servers>\n</settings>\n' "$SERVER" > "$SETTINGS"
  else
    cp "$SETTINGS" "$SETTINGS.bak-expert"
    if grep -q "<servers>" "$SETTINGS"; then
      awk -v s="$SERVER" '{print} /<servers>/ && !done {print s; done=1}' "$SETTINGS.bak-expert" > "$SETTINGS"
    else
      awk -v s="$SERVER" '{print} /<settings[ >]/ && !done {print "  <servers>\n" s "\n  </servers>"; done=1}' "$SETTINGS.bak-expert" > "$SETTINGS"
    fi
  fi
  chmod 600 "$SETTINGS"
  echo "Acesso aos pacotes Maven da ExpertCustom configurado."
}

# A última versão publicada, lida do GitHub Packages.
latest_version() {
  curl -fsSL -u "$USERNAME:$TOKEN" "$MAVEN_URL/br/com/expertcustom/fw/api/maven-metadata.xml" 2>/dev/null \
    | sed -n 's:.*<release>\(.*\)</release>.*:\1:p' | head -1
}

# ---- Java ------------------------------------------------------------------------------

if [ "$LANGUAGE" = "java" ]; then
  if ! command -v java >/dev/null 2>&1; then
    echo "Java não encontrado. Instale o Java 25 (Temurin): https://adoptium.net" >&2; exit 1
  fi
  JAVA_MAJOR=$(java -version 2>&1 | sed -n 's/.*version "\([0-9]*\).*/\1/p' | head -1)
  if [ "${JAVA_MAJOR:-0}" -lt 25 ]; then
    echo "Java $JAVA_MAJOR encontrado. O framework precisa do Java 25 ou mais novo." >&2; exit 1
  fi
  if ! command -v mvn >/dev/null 2>&1; then
    echo "Maven não encontrado. Instale o Maven: https://maven.apache.org" >&2; exit 1
  fi
  if ! command -v node >/dev/null 2>&1; then
    echo "Node não encontrado. As telas (React) precisam do Node 24 ou mais novo: https://nodejs.org" >&2; exit 1
  fi
  configure_maven
  configure_npm   # as telas vêm do create-app (npm)
  [ -z "$PROJECT" ] && PROJECT=$(ask "Nome da pasta do projeto: ")
  if [ -z "$PROJECT" ]; then echo "Informe o nome da pasta." >&2; exit 1; fi
  VERSION="${EXPERT_VERSION:-$(latest_version)}"
  if [ -z "$VERSION" ]; then echo "Não consegui descobrir a versão do framework. Confira o token." >&2; exit 1; fi
  echo "Criando o projeto \"$PROJECT\" com o framework Java $VERSION..."
  mvn -q "br.com.expertcustom.fw:expert-maven-plugin:$VERSION:create" -Dname="$PROJECT"
  exit 0
fi

# ---- TypeScript ------------------------------------------------------------------------

if ! command -v node >/dev/null 2>&1; then
  echo "Node não encontrado. Instale o Node 24 ou mais novo: https://nodejs.org" >&2; exit 1
fi
NODE_MAJOR=$(node -p "process.versions.node.split('.')[0]")
if [ "$NODE_MAJOR" -lt 24 ]; then
  echo "Node $(node -v) encontrado. O framework precisa do Node 24 ou mais novo." >&2; exit 1
fi
configure_npm
[ -z "$PROJECT" ] && PROJECT=$(ask "Nome da pasta do projeto: ")
if [ -z "$PROJECT" ]; then echo "Informe o nome da pasta." >&2; exit 1; fi
npm exec --yes --package="$CREATE_APP" -- create-app "$PROJECT" < /dev/tty
