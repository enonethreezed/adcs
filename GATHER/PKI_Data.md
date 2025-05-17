# Script Summary

This **PowerShell** script (which you can copy and paste directly into the console) connects to **Active Directory** in order to:

1. **Locate all certificate templates** under  
   `CN=Certificate Templates,CN=Public Key Services,CN=Services,<configDN>`  
   within the AD configuration partition.
2. **Retrieve attributes** of each template, such as:  
   - **DisplayName** or **CN** (the template’s name).  
   - **msPKI-AutoEnrollmentFlag** (indicating auto-enrollment settings, if present).  
   - **msPKI-EnrollmentFlag** (indicating certain enrollment configurations).  
3. **Read the Access Control List (ACL)** of the template, enumerating every **ACE** (Access Control Entry) to gather:  
   - The user/group to which it applies (`IdentityReference`).  
   - The **Active Directory rights** (`ActiveDirectoryRights`).  
   - The **Access control type** (`Allow` or `Deny`).  
   - The **GUID** to determine if it is an **Enroll** or **Autoenroll** extended right.  
4. It **aggregates** all this data into a **single CSV file**, where each row represents:  
   - An ACE (permission entry) for a particular template.  
   - Or a note indicating that the ACL could not be read or that it is empty for some reason.  
5. The CSV contains columns to help you filter or analyze permissions:  
   - `TemplateName`  
   - `AutoEnrollmentFlag`  
   - `EnrollmentFlag`  
   - `IdentityReference`  
   - `ActiveDirectoryRights`  
   - `AccessControlType`  
   - `ObjectTypeGUID`  
   - `IsExplicitEnroll`  
   - `IsExplicitAutoEnroll`  
6. The script appends a **timestamp** (date and time) to the CSV filename to avoid overwriting previous reports.

## Final Output

- A **CSV file** is created in the current PowerShell working directory (e.g., `C:\Temp\CertTemplates_Permissions_20250407_153000.csv`).  
- Each row describes a **permission** on a specific certificate template, allowing you to quickly determine **who has Enroll/Autoenroll rights** and view basic configuration flags of each template.
