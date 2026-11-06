# Instaladores da ExpertCustom

Um arquivo por produto. O instalador pergunta a linguagem (TypeScript ou Java), configura o acesso
aos pacotes privados (só na primeira vez em cada máquina) e cria um projeto novo.

## Framework

Linux e Mac:

```bash
curl -fsSL https://raw.githubusercontent.com/Expert-Custom/install/main/framework.sh | sh
```

Windows (PowerShell):

```powershell
iwr https://raw.githubusercontent.com/Expert-Custom/install/main/framework.ps1 -useb | iex
```

Para já escolher a linguagem, passe `--java` (ou `--ts`):

```bash
curl -fsSL https://raw.githubusercontent.com/Expert-Custom/install/main/framework.sh | sh -s -- --java
```

- **TypeScript:** precisa do Node 24+. Configura o `~/.npmrc` e roda o `create-app`.
- **Java:** precisa do Java 25+, do Maven e do Node 24+ (as telas são em React). Configura o
  `~/.m2/settings.xml` (servidor `expertcustom`) e o `~/.npmrc`, e cria o projeto com o
  `expert:create` (backend em Java, telas em React).

O token de acesso é o mesmo do GitHub (com permissão de leitura nos pacotes). No Java, o instalador
também pede o usuário do GitHub.
