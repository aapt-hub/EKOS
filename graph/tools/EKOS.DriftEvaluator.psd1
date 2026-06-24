@{
    RootModule        = 'EKOS.DriftEvaluator.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '16bbf914-57ad-47ed-b7ed-f7cf93192c29'
    Author            = 'Abner Pauneto'
    CompanyName       = 'EKOS'
    Copyright         = '(c) 2026 Abner Pauneto. All Rights Reserved.'
    Description       = 'Deterministic EKOS graph drift audit module.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Invoke-EkosGraphAudit')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags = @(
                'EKOS',
                'Graph',
                'Drift',
                'Identity',
                'Deterministic'
            )
        }
    }
}
