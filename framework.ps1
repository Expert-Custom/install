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

$Npmrc = Join-Path $HOME '.npmrc'
$HasToken = (Test-Path $Npmrc) -and (Select-String -Path $Npmrc -Pattern "//$Registry/:_authToken=" -SimpleMatch -Quiet)

if (-not $HasToken) {
  $Secure = Read-Host 'Token de acesso da ExpertCustom' -AsSecureString
  $Token = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure))
  if (-not $Token) {
    Write-Host 'Sem o token não dá para baixar o framework.'
    return
  }
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
}

$Project = Read-Host 'Nome da pasta do projeto'
if (-not $Project) {
  Write-Host 'Informe o nome da pasta.'
  return
}

npm exec --yes --package=$CreateApp -- create-app $Project
