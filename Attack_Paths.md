# AD CS: Summary of Attack Paths (ESCs)

This document provides an overview of the documented Enterprise Security Configurations (ESCs) that illustrate various attack paths in Active Directory Certificate Services (AD CS). These scenarios demonstrate how misconfigurations or overly permissive settings can be exploited to escalate privileges or maintain persistent access within a Windows domain.

---

## ESC1: Poorly Configured Templates (Broad EKU or Unrestricted)
- **Description:**  
  Templates with overly broad EKUs or insufficient restrictions allow users to request certificates that can be used to impersonate privileged accounts.
- **References:**  
  - [SpecterOps "Certified Pre-Owned" Whitepaper, pp. 7-8, 15](https://specterops.io/assets/resources/Certified_Pre-Owned.pdf)  
  - [ADCS Attack Paths in BloodHound, Part 1](https://medium.com/specter-ops-posts/adcs-attack-paths-in-bloodhound-part-1-799f3d3b03cf)

## ESC2: Abuse of the Enrollment Agent Template
- **Description:**  
  The Enrollment Agent template allows enrollment on behalf of other users. Abuse of this feature can enable an attacker to issue certificates for any account, including high-privilege ones.
- **References:**  
  - [SpecterOps "Certified Pre-Owned" Whitepaper, pp. 22-25](https://specterops.io/assets/resources/Certified_Pre-Owned.pdf)  
  - [Microsoft Documentation on Enrollment Agents](https://learn.microsoft.com/en-us/windows-server/administration/certification-authority/manage-certification-authority-role-services#manage-enrollment-agents)

## ESC3: Subject Alternative Name (SAN) Controlled by the Requester
- **Description:**  
  Allowing the requester to control the SAN (e.g., via `ENROLLEE_SUPPLIES_SUBJECT`) enables the issuance of certificates with UPNs or SIDs of privileged accounts.
- **References:**  
  - [SpecterOps "Certified Pre-Owned" Whitepaper, pp. 16-17](https://specterops.io/assets/resources/Certified_Pre-Owned.pdf)  
  - [ADCS Attack Paths in BloodHound, Part 2](https://medium.com/specter-ops-posts/adcs-attack-paths-in-bloodhound-part-2-ac7f925d1547)

## ESC4: Combination of Enrollment Agent and SAN Control
- **Description:**  
  Combining the ability to enroll on behalf of others with control over the SAN allows attackers to forge certificates for any identity.
- **References:**  
  - [SpecterOps "Certified Pre-Owned" Whitepaper, p. 25](https://specterops.io/assets/resources/Certified_Pre-Owned.pdf)  
  - [ADCS Attack Paths in BloodHound, Part 3](https://medium.com/specter-ops-posts/adcs-attack-paths-in-bloodhound-part-3-33efb00856ac)

## ESC5: Templates with Overly Permissive EKUs or "Any Purpose"
- **Description:**  
  Templates that use an "Any Purpose" EKU or combine multiple high-privilege EKUs (such as Server Authentication, Client Authentication, and Smart Card Logon) may be exploited for unintended uses.
- **References:**  
  - [SpecterOps "Certified Pre-Owned" Whitepaper, pp. 15-17](https://specterops.io/assets/resources/Certified_Pre-Owned.pdf)  
  - [ADCS Attack Paths in BloodHound, Part 1](https://medium.com/specter-ops-posts/adcs-attack-paths-in-bloodhound-part-1-799f3d3b03cf)

## ESC6: Excessive Permissions on the Template
- **Description:**  
  When broad groups (e.g., "Authenticated Users") are granted enrollment rights on high-privilege templates, any regular user could potentially obtain a certificate that provides unauthorized access.
- **References:**  
  - [SpecterOps "Certified Pre-Owned" Whitepaper, pp. 8-9](https://specterops.io/assets/resources/Certified_Pre-Owned.pdf)  
  - [ADCS Attack Paths in BloodHound, Part 1](https://medium.com/specter-ops-posts/adcs-attack-paths-in-bloodhound-part-1-799f3d3b03cf)

## ESC7: Improper Use of UPN Attributes in Certificates
- **Description:**  
  Failing to properly validate the User Principal Name (UPN) in a certificate request allows attackers to forge certificates with UPNs belonging to higher-privilege accounts.
- **References:**  
  - [SpecterOps "Certified Pre-Owned" Whitepaper, p. 16](https://specterops.io/assets/resources/Certified_Pre-Owned.pdf)  
  - [Certificate Template Reference – Microsoft Docs](https://learn.microsoft.com/en-us/windows-server/administration/certification-authority/certificate-templates/certificate-template-reference)

## ESC8: NTLM Relay to AD CS Web Enrollment Endpoints
- **Description:**  
  NTLM relay attacks (e.g., via [PetitPotam](https://github.com/topotam/PetitPotam)) can redirect authentication to the AD CS Web Enrollment interface, allowing an attacker to request certificates on behalf of a victim.
- **References:**  
  - [SpecterOps "Certified Pre-Owned" Whitepaper, pp. 37-40](https://specterops.io/assets/resources/Certified_Pre-Owned.pdf)  
  - [PetitPotam on GitHub](https://github.com/topotam/PetitPotam)

## ESC9: Vulnerable Subordinate or Offline CA Configurations
- **Description:**  
  A compromised subordinate or offline CA with weak security can enable an attacker to issue arbitrary certificates for any identity in the domain.
- **References:**  
  - [SpecterOps "Certified Pre-Owned" Whitepaper, pp. 45-47](https://specterops.io/assets/resources/Certified_Pre-Owned.pdf)  
  - [Planning and Designing a PKI – Microsoft Docs](https://learn.microsoft.com/en-us/windows-server/identity/ad-cs/plan/)

## ESC10: Misuse of Domain Controller Certificate Templates
- **Description:**  
  If templates intended for Domain Controllers are not properly restricted, attackers may issue certificates that allow them to impersonate a domain controller and gain near-total control.
- **References:**  
  - [SpecterOps "Certified Pre-Owned" Whitepaper, pp. 17-18](https://specterops.io/assets/resources/Certified_Pre-Owned.pdf)  
  - [ADCS Attack Paths in BloodHound, Part 2](https://medium.com/specter-ops-posts/adcs-attack-paths-in-bloodhound-part-2-ac7f925d1547)

## ESC11: Lack of Validation or Monitoring in Certificate Issuance
- **Description:**  
  A CA that issues certificates without sufficient approval or logging allows an attacker to obtain certificates unnoticed, facilitating persistence and lateral movement.
- **References:**  
  - [SpecterOps "Certified Pre-Owned" Whitepaper, pp. 9, 14](https://specterops.io/assets/resources/Certified_Pre-Owned.pdf)  
  - [ADCS Attack Paths in BloodHound, Part 3](https://medium.com/specter-ops-posts/adcs-attack-paths-in-bloodhound-part-3-33efb00856ac)

## ESC12: Poorly Managed Revocation and Expiration
- **Description:**  
  Certificates with long validity periods or weak revocation processes can allow compromised certificates to remain valid long after security measures have changed.
- **References:**  
  - [SpecterOps "Certified Pre-Owned" Whitepaper, pp. 14, 42](https://specterops.io/assets/resources/Certified_Pre-Owned.pdf)  
  - [Implementing Certificate Revocation – Microsoft Docs](https://learn.microsoft.com/en-us/windows-server/identity/ad-cs/plan/implementing-credential-roaming#revocation-and-renewal)

## ESC13: Abuse of `msDS-KeyCredentialLink` (Shadow Credentials)
- **Description:**  
  Exploiting the ability to modify the `msDS-KeyCredentialLink` attribute enables an attacker to associate their own key with a target account, bypassing password-based authentication.
- **References:**  
  - [ADCS ESC13 Abuse Technique – Medium](https://medium.com/specter-ops-posts/adcs-esc13-abuse-technique-fda4272fbd53)  
  - [SpecterOps "Certified Pre-Owned" Whitepaper, pp. 55-58](https://specterops.io/assets/resources/Certified_Pre-Owned.pdf)

## ESC14: Advanced Abuse of Public Key Configurations and Permissions
- **Description:**  
  This scenario involves manipulating public key pairs and authentication settings to bypass traditional controls, enabling persistent access and privilege escalation.
- **References:**  
  - [ADCS ESC14 Abuse Technique – Medium](https://medium.com/specter-ops-posts/adcs-esc14-abuse-technique-333a004dc2b9)  
  - [SpecterOps "Certified Pre-Owned" Whitepaper, pp. 58-62](https://specterops.io/assets/resources/Certified_Pre-Owned.pdf)
