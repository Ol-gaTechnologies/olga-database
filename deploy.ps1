[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ServerFqdn,
    [Parameter(Mandatory=$true)][string]$DatabaseName,
    [Parameter(Mandatory=$true)][string]$UserName,
    [ValidateSet('0','1')][string]$SeedMvpPolicies = '0'
)
$ErrorActionPreference = 'Stop'
$psql = Get-Command psql -ErrorAction Stop
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$previousSslMode = $env:PGSSLMODE
$env:PGSSLMODE = 'require'
Push-Location $root
try {
    & $psql.Source --host $ServerFqdn --port 5432 --dbname $DatabaseName --username $UserName --variable "seed_mvp_policies=$SeedMvpPolicies" --file '.\deploy.sql'
    if ($LASTEXITCODE -ne 0) { throw "psql deployment failed with exit code $LASTEXITCODE" }
}
finally {
    Pop-Location
    $env:PGSSLMODE = $previousSslMode
}
