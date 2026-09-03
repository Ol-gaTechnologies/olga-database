[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ServerFqdn,
    [Parameter(Mandatory=$true)][string]$DatabaseName,
    [ValidateSet('0','1')][string]$SeedMvpPolicies = '0'
)
$ErrorActionPreference = 'Stop'
$sqlcmd = Get-Command sqlcmd -ErrorAction Stop
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $root
try {
    & $sqlcmd.Source -S "tcp:$ServerFqdn,1433" -d $DatabaseName -G -N -l 60 -b -v "SeedMvpPolicies=$SeedMvpPolicies" -i ".\deploy.sql"
    if ($LASTEXITCODE -ne 0) { throw "sqlcmd deployment failed with exit code $LASTEXITCODE" }
}
finally { Pop-Location }
