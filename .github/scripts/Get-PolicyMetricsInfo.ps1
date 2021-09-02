<#
SUMMARY: This PowerShell script helps with the authoring of the policy definiton module by outputting information required for the variables within the module.
DESCRIPTION: This PowerShell script outputs the Name & Path to a Bicep strucutred .txt file named '_policyDefinitionsBicepInput.txt' and '_policySetDefinitionsBicepInput.txt' respectively. It also outputs the number of policies definition and set definition files to the console for easier reviewing as part of the PR process.
AUTHOR/S: jtracey93
VERSION: 1.0.0
#>

# Policy Definitions

Write-Information "====> Creating/Emptying '_policyDefinitionsBicepInput.txt'" -InformationAction Continue
Set-Content -Path "./infra-as-code/bicep/modules/policy/lib/policy_definitions/_policyDefinitionsBicepInput.txt" -Value $null -Encoding "utf8"

Write-Information "====> Looping Through Policy Definitions:" -InformationAction Continue
Get-ChildItem -Recurse -Path "./infra-as-code/bicep/modules/policy/lib/policy_definitions" -Filter "*.json" | ForEach-Object {
    $policyDef = Get-Content $_.FullName | ConvertFrom-Json -Depth 100
    
    $policyDefinitionName = $policyDef.name
    $fileName = $_.Name

    Write-Information "==> Adding '$policyDefinitionName' to '$PWD/_policyDefinitionsBicepInput.txt'" -InformationAction Continue
    Add-Content -Path "./infra-as-code/bicep/modules/policy/lib/policy_definitions/_policyDefinitionsBicepInput.txt" -Encoding "utf8" -Value "{`r`n  name: '$policyDefinitionName'`r`n  libDefinition: json(loadTextContent('lib/policy_definitions/$fileName'))`r`n}"
}

$policyDefCount = Get-ChildItem -Recurse -Path "./infra-as-code/bicep/modules/policy/lib/policy_definitions" -Filter "*.json" | Measure-Object 
$policyDefCountString = $policyDefCount.Count
Write-Information "====> Policy Definitions Total: $policyDefCountString" -InformationAction Continue

# Policy Set Definitions

Write-Information "====> Creating/Emptying '_policySetDefinitionsBicepInput.txt'" -InformationAction Continue
Set-Content -Path "./infra-as-code/bicep/modules/policy/lib/policy_set_definitions/_policySetDefinitionsBicepInput.txt" -Value $null -Encoding "utf8"

Write-Information "====> Looping Through Policy Set/Initiative Definition:" -InformationAction Continue
# Get-ChildItem -Recurse -Path "./infra-as-code/bicep/modules/policy/lib/policy_set_definitions" -Filter "*.json"  | ForEach-Object {
#     $policyDef = Get-Content $_.FullName | ConvertFrom-Json -Depth 100
    
#     $policyDefinitionName = $policyDef.name
#     $fileName = $_.Name

#     ## Add here for policyDefinitions array

#     $policyDefinitions = $policyDef.properties.policyDefinitions



#     Write-Information "==> Adding '$policyDefinitionName' to '$PWD/_policySetDefinitionsBicepInput.txt'" -InformationAction Continue
#     Add-Content -Path "./infra-as-code/bicep/modules/policy/lib/policy_set_definitions/_policySetDefinitionsBicepInput.txt" -Encoding "utf8" -Value "{`r`n  name: '$policyDefinitionName'`r`n  libDefinition: json(loadTextContent('lib/policy_set_definitions/$fileName'))`r`n}"
# }

Get-ChildItem -Recurse -Path "./infra-as-code/bicep/modules/policy/lib/policy_set_definitions" -Filter "*.json"  | ForEach-Object {
    $policyDef = Get-Content $_.FullName | ConvertFrom-Json -Depth 100
    
    $policyDefinitionName = $policyDef.name
    $fileName = $_.Name
    
    Clear-Variable -Name policySetDefinitionsOutputForBicep
    [System.Collections.Hashtable]$policySetDefinitionsOutputForBicep = @{}

    $policyDefinitions = $policyDef.properties.policyDefinitions

    $policyDefinitions | ForEach-Object {
        $policySetDefinitionsOutputForBicep.Add($_.policyDefinitionReferenceId, $_.policyDefinitionId) 
    }

    # Split the below Add-Content into multiple steps. 1. Before the array for the child definition IDs for each set 2. the bits after to close the array

    # Write-Information "==> Adding '$policyDefinitionName' to '$PWD/_policySetDefinitionsBicepInput.txt'" -InformationAction Continue
    Add-Content -Path "./infra-as-code/bicep/modules/policy/lib/policy_set_definitions/_policySetDefinitionsBicepInput.txt" -Encoding "utf8" -Value "{`r`n  name: '$policyDefinitionName'`r`n  libDefinition: json(loadTextContent('lib/policy_set_definitions/$fileName'))`r`n  libSetChildDefinitions: [`r`n      {`r`n        definitionReferenceId: $policyDefintionsReferenceIDForBicep  }"
}

$policyDefCount = Get-ChildItem -Recurse -Path "./infra-as-code/bicep/modules/policy/lib/policy_set_definitions" -Filter "*.json" | Measure-Object
$policyDefCountString = $policyDefCount.Count
Write-Information "====> Policy Set/Initiative Definitions Total: $policyDefCountString" -InformationAction Continue
