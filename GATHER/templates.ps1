# Generate the CSV path in the current directory, with a timestamp in the filename
$currentDir = (Get-Location).Path
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$csvPath = Join-Path $currentDir "CertTemplates_Permissions_$timestamp.csv"

Write-Host "The CSV file will be saved to: $csvPath"

# Get the configuration DN from RootDSE
$rootDSE = [ADSI]"LDAP://RootDSE"
$configDN = $rootDSE.configurationNamingContext

# Build the LDAP path to the certificate templates container
$templatesDN = "CN=Certificate Templates,CN=Public Key Services,CN=Services,$($configDN)"
$templatesContainer = [ADSI]("LDAP://$templatesDN")

# GUIDs for the Extended Rights Enroll and Autoenroll
$guidEnroll     = "6dc1789b-16c4-4fbb-b4fc-3f4077afa5a8"
$guidAutoEnroll = "a05b8cc2-17bc-4802-a710-e7c15ab866a2"

# GUID for "All Extended Rights" on an object (often includes enroll-like permissions)
$guidAllExtendedRights = "0e10c968-78fb-11d2-90d4-00c04f79dc55"

# List to store all results
$results = @()

# Enumerate each certificate template
foreach ($child in $templatesContainer.psBase.Children) {

    # 1) Template name
    $templateName = $child.Properties["displayName"]
    if (!$templateName -or $templateName.Count -eq 0) {
        $templateName = $child.Properties["cn"]
    }
    if (-not $templateName) {
        continue
    }
    $templateName = $templateName.ToString()

    # 2) msPKI-AutoEnrollmentFlag
    $autoEnrollmentFlag = $null
    if ($child.Properties["msPKI-AutoEnrollmentFlag"] -and $child.Properties["msPKI-AutoEnrollmentFlag"].Count -gt 0) {
        $autoEnrollmentFlag = $child.Properties["msPKI-AutoEnrollmentFlag"][0]
    }

    # 3) msPKI-EnrollmentFlag
    $enrollmentFlag = $null
    if ($child.Properties["msPKI-EnrollmentFlag"] -and $child.Properties["msPKI-EnrollmentFlag"].Count -gt 0) {
        $enrollmentFlag = $child.Properties["msPKI-EnrollmentFlag"][0]
    }

    # 4) Get the ACL
    $acl = $child.psBase.ObjectSecurity

    if ($acl) {
        $aceList = $acl.GetAccessRules($true, $true, [System.Security.Principal.NTAccount])

        if ($aceList.Count -eq 0) {
            # If no ACEs, insert a row indicating empty ACL
            $results += [PSCustomObject]@{
                TemplateName          = $templateName
                AutoEnrollmentFlag    = $autoEnrollmentFlag
                EnrollmentFlag        = $enrollmentFlag
                IdentityReference     = "(No ACEs in the ACL)"
                ActiveDirectoryRights = $null
                AccessControlType     = $null
                ObjectTypeGUID        = $null
                IsExplicitEnroll      = $false
                IsExplicitAutoEnroll  = $false
                HasBroadPower         = $false
            }
        }
        else {
            # For each ACE, build an object
            foreach ($ace in $aceList) {
                $isEnroll     = $false
                $isAutoEnroll = $false
                $hasBroadPower = $false

                # Detect explicit Enroll/Autoenroll
                if ($ace.ActiveDirectoryRights -match "ExtendedRight") {
                    if ($ace.ObjectType -eq $guidEnroll) {
                        $isEnroll = $true
                    }
                    elseif ($ace.ObjectType -eq $guidAutoEnroll) {
                        $isAutoEnroll = $true
                    }
                }

                # Check if this ACE gives broad control: GenericAll, WriteDACL, FullControl,
                # or "All Extended Rights" (0e10c968-78fb-11d2-90d4-00c04f79dc55).
                # You can adjust the conditions as needed.
                $rightsString = $ace.ActiveDirectoryRights.ToString()
                if (
                    $rightsString -match "GenericAll" -or
                    $rightsString -match "WriteDacl" -or
                    $rightsString -match "WriteOwner" -or
                    $rightsString -match "WriteProperty" -and 
                    $ace.ObjectType -eq $guidAllExtendedRights -or
                    ($ace.ObjectType -eq $guidAllExtendedRights)
                ) {
                    $hasBroadPower = $true
                }

                # Construct the final object
                $results += [PSCustomObject]@{
                    TemplateName          = $templateName
                    AutoEnrollmentFlag    = $autoEnrollmentFlag
                    EnrollmentFlag        = $enrollmentFlag
                    IdentityReference     = $ace.IdentityReference.ToString()
                    ActiveDirectoryRights = $ace.ActiveDirectoryRights.ToString()
                    AccessControlType     = $ace.AccessControlType.ToString()
                    ObjectTypeGUID        = $ace.ObjectType
                    IsExplicitEnroll      = $isEnroll
                    IsExplicitAutoEnroll  = $isAutoEnroll
                    HasBroadPower         = $hasBroadPower
                }
            }
        }
    }
    else {
        # Could not read the ACL
        $results += [PSCustomObject]@{
            TemplateName          = $templateName
            AutoEnrollmentFlag    = $autoEnrollmentFlag
            EnrollmentFlag        = $enrollmentFlag
            IdentityReference     = "(Could not read ACL)"
            ActiveDirectoryRights = $null
            AccessControlType     = $null
            ObjectTypeGUID        = $null
            IsExplicitEnroll      = $false
            IsExplicitAutoEnroll  = $false
            HasBroadPower         = $false
        }
    }
}

# Export results to CSV
$results | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

Write-Host "`nCSV created at: $csvPath"
