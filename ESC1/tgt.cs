// Warning! This code will create a EDR alert!!
// This is just test code, it will not work on a real scenario.
using System;
using System.Net;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Security.Cryptography.X509Certificates;

namespace PKINITExampleComplete
{
    class Program
    {
        static void Main(string[] args)
        {
            // Step 0: Load the certificate from a local file "cert.pfx" with the fixed password.
            string certFilePath = "cert.pfx";
            string certPassword = "password";
            X509Certificate2 certificate;
            try
            {
                certificate = new X509Certificate2(certFilePath, certPassword);
            }
            catch (Exception ex)
            {
                Console.WriteLine("Error loading certificate: " + ex.Message);
                return;
            }

            Console.WriteLine("Certificate loaded successfully:");
            Console.WriteLine("Subject: {certificate.Subject}");
            Console.WriteLine("Thumbprint: {certificate.Thumbprint}");

            // -----------------------------------------------------------------
            // Step 1: Acquire a credentials handle using the Kerberos package.
            // Note: In a real PKINIT implementation, the authData structure would
            // be populated with certificate-related information.
            // -----------------------------------------------------------------
            SECURITY_HANDLE credHandle;
            TimeStamp expiry;
            SEC_WINNT_AUTH_IDENTITY authData = new SEC_WINNT_AUTH_IDENTITY();
            // For this example, authData is left unpopulated.
            int acquireResult = AcquireCredentialsHandle(
                null,
                "Kerberos",
                SECPKG_CRED_OUTBOUND,
                IntPtr.Zero,
                ref authData,
                IntPtr.Zero,
                IntPtr.Zero,
                out credHandle,
                out expiry);

            if (acquireResult != SEC_E_OK)
            {
                Console.WriteLine("AcquireCredentialsHandle failed: 0x{0:X}", acquireResult);
                return;
            }
            Console.WriteLine("Credentials handle acquired.");

            // -----------------------------------------------------------------
            // Step 2: Initialize the security context to generate an initial token.
            // This token will be sent to the KDC.
            // -----------------------------------------------------------------
            SECURITY_HANDLE contextHandle;
            SecBufferDesc outSecBuffer;
            uint contextAttributes;
            TimeStamp contextExpiry;
            // First call: no existing context, so pass IntPtr.Zero for phContext.
            int initResult = InitializeSecurityContext(
                ref credHandle,
                IntPtr.Zero,
                "krbtgt/ludus.domain", // Target SPN for TGT request.
                ISC_REQ_MUTUAL_AUTH | ISC_REQ_DELEGATE,
                0,
                SECURITY_NATIVE_DREP,
                IntPtr.Zero,
                0,
                out contextHandle,
                out outSecBuffer,
                out contextAttributes,
                out contextExpiry);

            if (initResult != SEC_E_OK && initResult != SEC_I_CONTINUE_NEEDED)
            {
                Console.WriteLine("InitializeSecurityContext failed: 0x{0:X}", initResult);
                return;
            }
            Console.WriteLine("Initial security context established.");

            // Extract the token from the outSecBuffer (conceptually).
            byte[] token = SecBufferDescToByteArray(outSecBuffer);
            Console.WriteLine("Token generated, length: {0} bytes", token.Length);

            // -----------------------------------------------------------------
            // Step 3: Send the token to the KDC (port 88) and receive the response.
            // This is a simplified exchange using UDP.
            // -----------------------------------------------------------------
            byte[] kdcResponse = SendTokenToKDC(token, "ludus.domain");
            if (kdcResponse == null || kdcResponse.Length == 0)
            {
                Console.WriteLine("No response received from the KDC.");
                return;
            }
            Console.WriteLine("Received response from KDC, length: {0} bytes", kdcResponse.Length);

            // -----------------------------------------------------------------
            // Step 4: Feed the KDC response back into InitializeSecurityContext.
            // This uses the second overload with a reference to the existing context.
            // -----------------------------------------------------------------
            SecBufferDesc inSecBuffer = CreateSecBufferDesc(kdcResponse);
            SECURITY_HANDLE newContextHandle;
            SecBufferDesc newOutSecBuffer;
            int initResult2 = InitializeSecurityContext(
                ref credHandle,
                ref contextHandle, // Use the previously acquired context.
                "krbtgt/ludus.domain",
                ISC_REQ_MUTUAL_AUTH | ISC_REQ_DELEGATE,
                0,
                SECURITY_NATIVE_DREP,
                ref inSecBuffer,
                0,
                out newContextHandle,
                out newOutSecBuffer,
                out contextAttributes,
                out contextExpiry);

            if (initResult2 != SEC_E_OK && initResult2 != SEC_I_CONTINUE_NEEDED)
            {
                Console.WriteLine("Second call to InitializeSecurityContext failed: 0x{0:X}", initResult2);
                return;
            }
            Console.WriteLine("Security context updated. PKINIT exchange completed (conceptually).");

            // In a full implementation, the final output token would contain the TGT.
            // Cleanup and further processing would follow.
        }

        // Converts a SecBufferDesc to a byte array containing the token.
        static byte[] SecBufferDescToByteArray(SecBufferDesc desc)
        {
            // Placeholder: In a real implementation, you would marshal the SecBuffer structures to extract the token.
            // For demonstration purposes, we'll assume there is one buffer.
            if (desc.cBuffers < 1 || desc.pBuffers == IntPtr.Zero)
                return new byte[0];

            SecBuffer buffer = (SecBuffer)Marshal.PtrToStructure(desc.pBuffers, typeof(SecBuffer));
            byte[] token = new byte[buffer.cbBuffer];
            Marshal.Copy(buffer.pvBuffer, token, 0, (int)buffer.cbBuffer);
            return token;
        }

        // Creates a SecBufferDesc structure from the given byte array.
        static SecBufferDesc CreateSecBufferDesc(byte[] data)
        {
            SecBuffer buffer = new SecBuffer
            {
                cbBuffer = (uint)data.Length,
                BufferType = 2, // SECBUFFER_TOKEN typically
                pvBuffer = Marshal.AllocHGlobal(data.Length)
            };
            Marshal.Copy(data, 0, buffer.pvBuffer, data.Length);

            SecBufferDesc desc = new SecBufferDesc
            {
                ulVersion = 0,
                cBuffers = 1,
                pBuffers = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(SecBuffer)))
            };
            Marshal.StructureToPtr(buffer, desc.pBuffers, false);
            return desc;
        }

        // Sends the token to the KDC via UDP and returns the response.
        static byte[] SendTokenToKDC(byte[] token, string domain)
        {
            try
            {
                UdpClient udpClient = new UdpClient();
                udpClient.Client.ReceiveTimeout = 5000;
                IPAddress[] addresses = Dns.GetHostAddresses(domain);
                if (addresses.Length == 0)
                {
                    Console.WriteLine("Unable to resolve domain: " + domain);
                    return null;
                }
                IPEndPoint kdcEndPoint = new IPEndPoint(addresses[0], 88);
                udpClient.Send(token, token.Length, kdcEndPoint);
                IPEndPoint remoteEP = null;
                byte[] response = udpClient.Receive(ref remoteEP);
                udpClient.Close();
                return response;
            }
            catch (Exception ex)
            {
                Console.WriteLine("Error communicating with KDC: " + ex.Message);
                return null;
            }
        }

        // ------------------ P/Invoke and Constants Definitions ------------------

        public const int SECPKG_CRED_OUTBOUND = 2;
        public const int SECURITY_NATIVE_DREP = 0x00000010;
        public const int ISC_REQ_MUTUAL_AUTH = 0x00000002;
        public const int ISC_REQ_DELEGATE = 0x00000001;
        public const int SEC_E_OK = 0x00000000;
        public const int SEC_I_CONTINUE_NEEDED = 0x00090312;

        [StructLayout(LayoutKind.Sequential)]
        public struct SECURITY_HANDLE
        {
            public IntPtr dwLower;
            public IntPtr dwUpper;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct TimeStamp
        {
            public uint LowPart;
            public int HighPart;
        }

        // Authentication data structure for AcquireCredentialsHandle.
        // A full implementation would populate these fields as needed for PKINIT.
        [StructLayout(LayoutKind.Sequential)]
        public struct SEC_WINNT_AUTH_IDENTITY
        {
            // Define fields as necessary.
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct SecBuffer
        {
            public uint cbBuffer;
            public uint BufferType;
            public IntPtr pvBuffer;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct SecBufferDesc
        {
            public uint ulVersion;
            public uint cBuffers;
            public IntPtr pBuffers; // Pointer to one or more SecBuffer structures.
        }

        // First overload: for the initial call (no existing context).
        [DllImport("secur32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        public static extern int InitializeSecurityContext(
            ref SECURITY_HANDLE phCredential,
            IntPtr phContext,
            string pszTargetName,
            int fContextReq,
            int Reserved1,
            int TargetDataRep,
            IntPtr pInput,
            int Reserved2,
            out SECURITY_HANDLE phNewContext,
            out SecBufferDesc pOutput,
            out uint pfContextAttr,
            out TimeStamp ptsExpiry);

        // Second overload: for subsequent calls (with an existing context).
        [DllImport("secur32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        public static extern int InitializeSecurityContext(
            ref SECURITY_HANDLE phCredential,
            ref SECURITY_HANDLE phContext,
            string pszTargetName,
            int fContextReq,
            int Reserved1,
            int TargetDataRep,
            ref SecBufferDesc pInput,
            int Reserved2,
            out SECURITY_HANDLE phNewContext,
            out SecBufferDesc pOutput,
            out uint pfContextAttr,
            out TimeStamp ptsExpiry);

        [DllImport("secur32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        public static extern int AcquireCredentialsHandle(
            string pszPrincipal,
            string pszPackage,
            int fCredentialUse,
            IntPtr pvLogonID,
            ref SEC_WINNT_AUTH_IDENTITY pAuthData,
            IntPtr pGetKeyFn,
            IntPtr pvGetKeyArgument,
            out SECURITY_HANDLE phCredential,
            out TimeStamp ptsExpiry);
    }
}

