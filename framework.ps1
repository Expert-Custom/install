$ErrorActionPreference = 'Stop'

# Instalador do framework ExpertCustom. Cria um projeto novo em TypeScript ou em Java.
#   iwr ... -useb | iex                      # pergunta tudo
#   & ([scriptblock]::Create((iwr ...))) --java

param()

$Language = ''
$Project = ''
foreach ($arg in $args) {
  switch ($arg) {
    { $_ -in '--ts', '--typescript' } { $Language = 'ts' }
    '--java' { $Language = 'java' }
    default { if (-not $arg.StartsWith('--') -and -not $Project) { $Project = $arg } }
  }
}

$NpmRegistry = 'npm.pkg.github.com'
$MavenUrl = 'https://maven.pkg.github.com/Expert-Custom/framework-java'
$CreateApp = if ($env:EXPERT_CREATE_APP) { $env:EXPERT_CREATE_APP } else { '@expert-custom/create-app@latest' }
$Token = ''
$Username = ''

# Só o token é perguntado. O usuário do GitHub, que o Maven exige, sai do próprio token.
$Npmrc = Join-Path $HOME '.npmrc'
$Settings = Join-Path (Join-Path $HOME '.m2') 'settings.xml'

# O token salvo no ~/.npmrc por uma instalação anterior.
function Get-SavedNpmToken {
  if (-not (Test-Path $Npmrc)) { return '' }
  $line = Select-String -Path $Npmrc -Pattern "^//$NpmRegistry/:_authToken=(.+)$" | Select-Object -First 1
  if ($line) { return $line.Matches[0].Groups[1].Value }
  return ''
}

# O usuário ou o token (username|password) do servidor expertcustom no ~/.m2/settings.xml.
function Get-SavedMaven($tag) {
  if (-not (Test-Path $Settings)) { return '' }
  $text = Get-Content -Raw $Settings
  if ($text -match "(?s)<id>expertcustom</id>.*?<$tag>(.*?)</$tag>") { return $Matches[1] }
  return ''
}

# O login do dono do token, perguntado ao GitHub.
function Get-GitHubLogin {
  try {
    $user = Invoke-RestMethod -Uri 'https://api.github.com/user' -Headers @{ Authorization = "Bearer $script:Token"; 'User-Agent' = 'expertcustom-install' }
    return $user.login
  } catch { return '' }
}

# O token: o já salvo ou, na primeira vez, perguntado.
function Read-Token {
  if ($script:Token) { return }
  $script:Token = Get-SavedNpmToken
  if ($script:Token) { return }
  $secure = Read-Host 'Token de acesso da ExpertCustom' -AsSecureString
  $script:Token = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
  if (-not $script:Token) { Write-Host 'Sem o token não dá para baixar o framework.'; exit 1 }
}

function Set-NpmAccess {
  $npmrc = $Npmrc
  if ((Test-Path $npmrc) -and (Select-String -Path $npmrc -Pattern "//$NpmRegistry/:_authToken=" -SimpleMatch -Quiet)) { return }
  Read-Token
  $lines = @()
  if (Test-Path $npmrc) {
    $lines = Get-Content $npmrc | Where-Object {
      -not $_.StartsWith('@expert-custom:registry=') -and -not $_.StartsWith("//$NpmRegistry/:_authToken=")
    }
  }
  $lines += "@expert-custom:registry=https://$NpmRegistry"
  $lines += "//$NpmRegistry/:_authToken=$script:Token"
  Set-Content -Path $npmrc -Value $lines
  Write-Host 'Acesso aos pacotes npm da ExpertCustom configurado.'
}

function Set-MavenAccess {
  $settings = $Settings
  if ((Test-Path $settings) -and (Select-String -Path $settings -Pattern '<id>expertcustom</id>' -SimpleMatch -Quiet)) {
    # Já configurado: usa o que está lá (a versão mais nova é lida com ele).
    $script:Username = Get-SavedMaven 'username'
    $script:Token = Get-SavedMaven 'password'
    return
  }
  Read-Token
  $script:Username = Get-GitHubLogin
  if (-not $script:Username) { Write-Host 'O GitHub não aceitou o token. Confira se ele está certo e tem a permissão read:packages.'; exit 1 }
  $server = "    <server>`n      <id>expertcustom</id>`n      <username>$script:Username</username>`n      <password>$script:Token</password>`n    </server>"
  New-Item -ItemType Directory -Force -Path (Split-Path $settings) | Out-Null
  if (-not (Test-Path $settings)) {
    Set-Content -Path $settings -Value "<settings>`n  <servers>`n$server`n  </servers>`n</settings>"
  } else {
    Copy-Item $settings "$settings.bak-expert"
    $text = Get-Content -Raw $settings
    if ($text -match '<servers>') {
      $text = $text -replace '<servers>', "<servers>`n$server"
    } else {
      $text = $text -replace '(<settings[^>]*>)', "`$1`n  <servers>`n$server`n  </servers>"
    }
    Set-Content -Path $settings -Value $text
  }
  Write-Host 'Acesso aos pacotes Maven da ExpertCustom configurado.'
}

function Get-LatestVersion {
  $pair = "$($script:Username):$($script:Token)"
  $auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
  $xml = Invoke-RestMethod -Uri "$MavenUrl/br/com/expertcustom/fw/api/maven-metadata.xml" -Headers @{ Authorization = "Basic $auth" }
  return $xml.metadata.versioning.latest   # o GitHub Packages informa só o <latest>, não o <release>
}

if (-not $Language) {
  Write-Host 'Em que linguagem é o projeto?'
  Write-Host '  1) TypeScript (padrão)'
  Write-Host '  2) Java'
  if ((Read-Host 'Digite o número [1]') -eq '2') { $Language = 'java' } else { $Language = 'ts' }
}

if ($Language -eq 'java') {
  if (-not (Get-Command java -ErrorAction SilentlyContinue)) { Write-Host 'Java não encontrado. Instale o Java 25: https://adoptium.net'; return }
  $javaMajor = [int]((java -version 2>&1)[0] -replace '.*version "(\d+).*', '$1')
  if ($javaMajor -lt 25) { Write-Host "Java $javaMajor encontrado. O framework precisa do Java 25 ou mais novo."; return }
  if (-not (Get-Command mvn -ErrorAction SilentlyContinue)) { Write-Host 'Maven não encontrado: https://maven.apache.org'; return }
  if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Write-Host 'Node não encontrado. As telas precisam do Node 24+: https://nodejs.org'; return }
  Set-MavenAccess
  Set-NpmAccess
  if (-not $Project) { $Project = Read-Host 'Nome da pasta do projeto' }
  if (-not $Project) { Write-Host 'Informe o nome da pasta.'; return }
  $version = if ($env:EXPERT_VERSION) { $env:EXPERT_VERSION } else { Get-LatestVersion }
  Write-Host "Criando o projeto `"$Project`" com o framework Java $version..."
  mvn -q "br.com.expertcustom.fw:expert-maven-plugin:$version`:create" "-Dname=$Project"
  return
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Write-Host 'Node não encontrado. Instale o Node 24 ou mais novo: https://nodejs.org'; return }
$nodeMajor = [int](node -p "process.versions.node.split('.')[0]")
if ($nodeMajor -lt 24) { Write-Host "Node $(node -v) encontrado. O framework precisa do Node 24 ou mais novo."; return }
Set-NpmAccess
if (-not $Project) { $Project = Read-Host 'Nome da pasta do projeto' }
if (-not $Project) { Write-Host 'Informe o nome da pasta.'; return }
npm exec --yes --package=$CreateApp -- create-app $Project
