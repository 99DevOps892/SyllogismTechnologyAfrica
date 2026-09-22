using System;
using System.Runtime.InteropServices;
using System.Text;

public static class CredSnapReader
{
    public static string Read(string target)
    {
        IntPtr credPtr;
        if (!CredReadW(target, 1, 0, out credPtr)) return null;
        try
        {
            var c = (Credential)Marshal.PtrToStructure(credPtr, typeof(Credential));
            var bytes = new byte[c.CredentialBlobSize];
            Marshal.Copy(c.CredentialBlob, bytes, 0, c.CredentialBlobSize);
            return Encoding.UTF8.GetString(bytes);
        }
        finally
        {
            CredFree(credPtr);
        }
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct Credential
    {
        public uint Flags;
        public uint Type;
        public IntPtr TargetName;
        public IntPtr Comment;
        public long LastWritten;
        public int CredentialBlobSize;
        public IntPtr CredentialBlob;
        public uint Persist;
        public int AttributeCount;
        public IntPtr Attributes;
        public IntPtr TargetAlias;
        public IntPtr UserName;
    }

    [DllImport("advapi32.dll", CharSet = CharSet.Unicode)]
    static extern bool CredReadW(string target, int type, int flags, out IntPtr credentialRail);

    [DllImport("advapi32.dll")]
    static extern bool CredFree(IntPtr cred);
}