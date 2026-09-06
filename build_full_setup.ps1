[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$output = Join-Path $root 'OLGA_Connect_AzureSQL_Full_Setup.sql'
$sections = @(
    @{ Label = 'SCHEMAS AND SEQUENCES'; File = '001_schemas_sequences.sql' },
    @{ Label = 'TABLES'; File = '010_tables.sql' },
    @{ Label = 'CONSTRAINTS AND INDEXES'; File = '020_constraints_indexes.sql' },
    @{ Label = 'CROSS-ROW INVARIANTS'; File = '025_invariants.sql' },
    @{ Label = 'CONTROLLED VIEWS'; File = '030_views.sql' },
    @{ Label = 'CONTROLLED PROCEDURES'; File = '040_procedures.sql' },
    @{ Label = 'REFERENCE DATA'; File = '050_seed.sql' },
    @{ Label = 'DATABASE ROLES AND GRANTS'; File = '060_security.sql' },
    @{ Label = 'VERIFICATION'; File = '090_verify.sql' }
)
$parts = [System.Collections.Generic.List[string]]::new()
$parts.Add(@'
/*
OLGA Connect Release 1 - Azure SQL full database setup
Architecture baseline: Database Architecture and Table-Level Design v2.3
Implementation baseline: MVP Architecture Implementation Guide v1.0
Target: a new, empty Azure SQL Database

This script is additive and does not drop objects. Provisional QA notification-policy
seeding is disabled in this standalone build until product and security approve it.
*/
'@)
foreach ($section in $sections) {
    $parts.Add("`r`n-- ======================== $($section.Label) ========================`r`n")
    $text = [System.IO.File]::ReadAllText((Join-Path $root $section.File))
    if ($section.File -eq '050_seed.sql') {
        $text = $text.Replace("IF '`$(SeedMvpPolicies)'='1'", 'IF 0=1')
    }
    $parts.Add($text.TrimEnd() + "`r`n")
}
[System.IO.File]::WriteAllText($output, ($parts -join ''), [System.Text.UTF8Encoding]::new($false))
Write-Output $output
