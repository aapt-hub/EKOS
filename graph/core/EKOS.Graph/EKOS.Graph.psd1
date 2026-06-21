@{
    RootModule        = 'EKOS.Graph.psm1'
    ModuleVersion     = '3.5.0'
	GUID              = 'ff920e05-6485-491b-b4eb-665374a68474'
    Author            = 'EKOS'
    CompanyName       = 'EKOS'
    Description       = 'EKOS Graph Engine v3'

    PowerShellVersion = '5.1'

    FunctionsToExport = @(
        'Invoke-EKOSQuery'
    )

    CmdletsToExport   = @()
    VariablesToExport  = @()
    AliasesToExport    = @()
}