function Invoke-CIPPStandardAppDeploy {
    <#
    .FUNCTIONALITY
        Internal
    .COMPONENT
        (APIName) AppDeploy
    .SYNOPSIS
        (Label) Deploy Application
    .DESCRIPTION
        (Helptext) Deploys selected applications to the tenant. Use a comma separated list of application IDs to deploy multiple applications. Permissions will be copied from the source application.
        (DocsDescription) Uses the CIPP functionality that deploys applications across an entire tenant base as a standard.
    .NOTES
        CAT
            Entra (AAD) Standards
        TAG
        ADDEDCOMPONENT
            {"type":"textField","name":"standards.AppDeploy.appids","label":"Application IDs, comma separated"}
        IMPACT
            Low Impact
        ADDEDDATE
            2024-07-07
        POWERSHELLEQUIVALENT
            Portal or Graph API
        RECOMMENDEDBY
        UPDATECOMMENTBLOCK
            Run the Tools\Update-StandardsComments.ps1 script to update this comment block
    .LINK
        https://docs.cipp.app/user-documentation/tenant/standards/list-standards/entra-aad-standards#low-impact
    #>

    param($Tenant, $Settings)
    $AppsToAdd = $Settings.appids -split ','

    If ($Settings.remediate -eq $true) {
        ##$Rerun -Type Standard -Tenant $Tenant -Settings $Settings 'AppDeploy'
        if ($Rerun -eq $true) {
            exit 0
        }
        foreach ($App In $AppsToAdd) {
            try {
                New-CIPPApplicationCopy -App $App -Tenant $Tenant
                Write-LogMessage -API 'Standards' -tenant $tenant -message "Added $App to $Tenant and update it's permissions" -sev Info
            } catch {
                $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
                Write-LogMessage -API 'Standards' -tenant $tenant -message "Failed to add app $App. Error: $ErrorMessage" -sev Error
            }
        }
    }

    if ($Settings.alert) {
        $AppExists = New-GraphGetRequest -uri 'https://graph.microsoft.com/beta/servicePrincipals?$top=999' -tenantid $Tenant
        $MissingApps = foreach ($App in $AppsToAdd) {
            try {
                if ($App -notin $AppExists.appId) {
                    $App
                }
            } catch {
                $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
                Write-LogMessage -API 'Standards' -tenant $tenant -message "Failed to check app $App. Error: $ErrorMessage" -sev Error
            }
        }

        if ($MissingApps.Count -gt 0) {
            Write-StandardsAlert -message "The following applications are not deployed: $($MissingApps -join ', ')" -object (@{ 'Missing Apps' = $MissingApps -join ',' }) -tenant $Tenant -standardName 'AppDeploy' -standardId $Settings.standardId
            Write-LogMessage -API 'Standards' -tenant $tenant -message "The following applications are not deployed: $($MissingApps -join ', ')" -sev Info
        } else {
            Write-LogMessage -API 'Standards' -tenant $tenant -message 'All applications are deployed' -sev Info
        }
    }

    if ($Settings.report -eq $true) {
        $StateIsCorrect = $MissingApps.Count -eq 0 ? $true : @{ 'Missing Apps' = $MissingApps -join ',' }
        Set-CIPPStandardsCompareField -FieldName 'standards.AppDeploy' -FieldValue $StateIsCorrect -TenantFilter $tenant
        Add-CIPPBPAField -FieldName 'AppDeploy' -FieldValue $StateIsCorrect -StoreAs bool -Tenant $tenant
    }
}
