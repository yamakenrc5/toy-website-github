$githubOrganizationName = 'yamakenrc5'
$githubRepositoryName = 'toy-website-github'

$applications = Get-AzADApplication -Filter "displayName eq '$githubRepositoryName'"

# Remove each previous application instance before proceeding 
foreach ($app in $applications) {
    if ($app.AppId) {
        Remove-AzADApplication -ApplicationId $app.AppId
    }
}


$applicationRegistration = New-AzADApplication -DisplayName $githubRepositoryName

$appset = @{
    Name = $githubRepositoryName
    ApplicationObjectId = $applicationRegistration.Id
    Issuer = 'https://token.actions.githubusercontent.com'
    Audience = 'api://AzureADTokenExchange'
    Subject = "repo:$($githubOrganizationName)/`
        $($githubRepositoryName):environment:Website"
}

New-AzADAppFederatedCredential @appset

# New-AzADAppFederatedCredential `
#    -Name 'toy-website-test' `
#    -ApplicationObjectId $applicationRegistration.Id `
#    -Issuer 'https://token.actions.githubusercontent.com' `
#    -Audience 'api://AzureADTokenExchange' `
#    -Subject "repo:$($githubOrganizationName)/$($githubRepositoryName):environment:Website"

$rgset = @{
    Name = 'ToyWebsite'
    Location = 'westus'
}
$RoleDefinitionName = 'Contributor'

# Ensure $rgset is defined and has necessary properties
if (-not $rgset -or -not $rgset.Name) {
    Write-Error "rgset is not defined or does not contain a Name property"
    return
}

# Check if $resourceGroup is null
if (-not $resourceGroup) {
    try {
        # Attempt to create a new resource group
        $resourceGroup = New-AzResourceGroup @rgset -Force
    } catch {
        Write-Error "Failed to create new resource group: $_"
        return
    }
} else {
    try {
        # Attempt to get the existing resource group
        $resourceGroup = Get-AzResourceGroup -Name $rgset.Name
    } catch {
        Write-Error "Failed to get existing resource group: $_"
        return
    }
}

$assignset = @{
    ApplicationId = $applicationRegistration.AppId
    RoleDefinitionName = $RoleDefinitionName
    Scope = $resourceGroup.ResourceId
    Description = "Role '"+$RoleDefinitionName +`
    "' is now configured in "+(Get-Date -Format 'dd-MMM-yyyy, HH:mm:ss')
}

# command body
# obtain a service principal. Not with client secret.
New-AzADServicePrincipal -AppId $assignset.ApplicationId

# create a role assignment
New-AzRoleAssignment @assignset

# prepare GitHub secrets (for the managed identifier)
$azureContext = Get-AzContext
Write-Host "AZURE_CLIENT_ID: $($applicationRegistration.AppId)"
Write-Host "AZURE_TENANT_ID: $($azureContext.Tenant.Id)"
Write-Host "AZURE_SUBSCRIPTION_ID: $($azureContext.Subscription.Id)"

# Still federated identity is not working, updating the existing permission sets:
az ad sp create-for-rbac --name $rgset.Name --role $RoleDefinitionName `
                            --scopes /subscriptions/$($azureContext.Subscription.Id)/resourceGroups/$($rgset.Name) `
                            --sdk-auth