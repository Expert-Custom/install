$ErrorActionPreference = 'Stop'

$Registry = 'npm.pkg.github.com'
$CreateApp = if ($env:EXPERT_CREATE_APP) { $env:EXPERT_CREATE_APP } else { '@expert-custom/create-app@latest' }

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  Write-Host 'Node não encontrado. Instale o Node 24 ou mais novo: https://nodejs.org'
  return
}

$NodeMajor = [int](node -p "process.versions.node.split('.')[0]")
if ($NodeMajor -lt 24) {
  Write-Host "Node $(node -v) encontrado. O framework precisa do Node 24 ou mais novo."
  return
}

$Token = Read-Host 'Token de acesso'
$Project = Read-Host 'Pasta do projeto'
if (-not $Token -or -not $Project) {
  Write-Host 'Token e pasta do projeto são obrigatórios.'
  return
}

$Npmrc = Join-Path $HOME '.npmrc'
$Lines = @()
if (Test-Path $Npmrc) {
  $Lines = Get-Content $Npmrc | Where-Object {
    -not $_.StartsWith('@expert-custom:registry=') -and -not $_.StartsWith("//$Registry/:_authToken=")
  }
}
$Lines += "@expert-custom:registry=https://$Registry"
$Lines += "//$Registry/:_authToken=$Token"
Set-Content -Path $Npmrc -Value $Lines
Write-Host 'Acesso aos pacotes da ExpertCustom configurado.'

npm exec --yes --package=$CreateApp -- create-app $Project
