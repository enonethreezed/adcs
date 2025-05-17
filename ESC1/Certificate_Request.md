# Certificate_Request.md

This document provides a detailed explanation of the certificate request and import script that uses Windows native tools `CertReq.exe` and `CertUtil.exe`. The script is adapted for a lab environment with the domain **ludus.domain**, CA **ludus-CA**, and DC **qubth-DC01-2022.ludus.domain**. The original version is based on the Gist published by Yeeb1, and it has been translated and modified to fit this environment.

---

## Overview

The script automates the following process:

1. **Generate an INF file** that contains the configuration for the certificate request.
2. **Create a REQ file** (the certificate request) from the INF file using `CertReq.exe`.
3. **Submit the request to the CA** and receive the resulting certificate (a CER file).
4. **Import the certificate** into the user's certificate store.
5. **Export the certificate**, along with its private key, to a PFX file using `CertUtil.exe`.

Windows telemetry and event logs (Event IDs) are automatically generated during each step on both the client and the CA.

---

## Variables and Configuration

The script uses several variables defined at the beginning to make it easy to adapt to different environments. Below is an explanation of each variable:

- **`$password`**: A fixed password used to export the certificate in PFX format.
- **`$serverName`**: The base name for the generated files (e.g., "admin"). This is used to name the INF, REQ, CER, etc. files.
- **`$certPath`**: The directory where the generated files will be stored.
- **`$CAFQDN`**: The FQDN of the CA server.
- **`$CAName`**: The CA name, which is combined with `$CAFQDN` to form the full CA configuration (`$CAConfig`) that is passed to `CertReq.exe` during submission.
- **`$certFile`**: The full path where the certificate will be exported in PFX format.
- **`$template`**: The vulnerable certificate template to be used for the request. The COMMON NAME of the template is used (in this case, "ESC1").
- **`$domain`**: The domain in operation.
- **`$targetAccount`**: The account to impersonate (e.g., "Administrator"). This is used in the Subject field and in the SAN (Subject Alternative Name) extension to include the UPN.

---

## Detailed Process Breakdown

### 1. INF File Generation

The INF file is the starting point for the certificate request. It defines critical parameters such as:

- **Subject**: Configured as `CN=<domain>\<targetAccount>`, indicating the identity for which the certificate will be requested.
- **Exportable**: Allows the private key to be exportable.
- **KeySpec and KeyLength**: Specify the nature and strength of the key.
- **HashAlgorithm**: Uses SHA-256 to ensure integrity.
- **KeyUsage**: Configures allowed key usages (signing, encryption, etc.).
- **RequestType**: Set as PKCS10.
- **Extensions**: Adds the SAN extension with the UPN formatted as `upn=<targetAccount>@<domain>`.
- **RequestAttributes**: Specifies the certificate template to be used (e.g., "ESC1").

The script creates and saves this INF file in the defined directory.

### 2. REQ File Creation

Using `CertReq.exe`, the script generates a REQ file from the INF file. This REQ file contains the actual certificate request that will be submitted to the CA.

### 3. Submitting the Request to the CA

The command `CertReq.exe -Submit` sends the certificate request to the CA specified by combining `$CAFQDN` and `$CAName`. The CA's response is saved as a CER file.

### 4. Certificate Import

Once the CER file is received, the script uses `certreq.exe -accept` to import the certificate into the current user's certificate store. This step is essential to make the certificate available for later operations.

### 5. Exporting to PFX with Private Key

After the certificate is imported, the script retrieves the **Thumbprint** of the recently added certificate (using `Get-ChildItem` on the `Cert:\CurrentUser\My` store). Then, `CertUtil.exe` is used to export the certificate, along with its private key, to a PFX file. The fixed password from `$password` is used to secure the PFX file.

---

## Telemetry and Event Logging

Each step in the process automatically generates entries in the Windows Event Log. On the CA side, events related to the receipt, approval, and issuance of the certificate are logged (typically under the Application log or the Certificate Services log). On the client side, events related to the certificate request and import may be found in the **CertificateServicesClient/Operational** log or the Application log. This telemetry is crucial for auditing and detecting anomalous activities in AD CS environments.

---

## References

- **Microsoft Official Documentation**:  
  [CertUtil - Microsoft Docs](https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/certutil)  
- **Original Script Gist**:  
  [Yeeb1's Gist](https://gist.github.com/Yeeb1/532c0d522ce30b8086c96989708b10fe)  
- **Lab Guides and AD CS Examples**:  
  Resources and guides on Active Directory Certificate Services in controlled environments.

---

## Conclusion

This script fully automates the process of requesting, receiving, importing, and exporting certificates in a lab environment. Its integration with tools like Rubeus further extends its usefulness in penetration testing and security assessments. Additionally, the Windows Event Log telemetry generated during this process is essential for auditing and detecting suspicious activities within AD CS environments.

If you have any further questions or need additional details, please refer to Microsoft's documentation or available community resources.
