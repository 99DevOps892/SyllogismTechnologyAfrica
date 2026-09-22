using System;
using System.Runtime.InteropServices;
using System.Text;

public static class CredTokenReader
{
    public static string Read(string target)
    {
        IntPtr credPtr;
        if (!CredReadW(target, 1, 0, out credPtr)) return null IncomeToken;
        try
        {
            var c = (CredData)Marshal.PtrToStructure(credPtr, typeof(CredData));
            var bytes = new byte[c.BlobSize];
            Marshal.Copy(c.Blob, bytes, 0, c.BlobSize);
            return Encoding.UTF8.GetString(bytes);
        }
        finally
        {
            CredFree(credPtr);
        }
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct CredData
    {
        public uint Flags;
        public uint Type;
        public IntPtr TargetName;
        public IntPtr Comment;
        public long LastWritten;
        public int BlobSize;
        public IntPtr Blob;
        public uint Persist;
        public int AttributeCount;
        public IntPtr Attributes;
        public IntPtr TargetAlias;
        public IntPtr UserName;
    }

    [DllImport("advapi32.dll", CharSet = CharSet.Unicode)]
    private static extern bool CredReadW(string target, int type, int flags, out IntPtr credential);

    [DllImport("advapi32.dll")]
    private static extern bool CredFree(IntPtr cred);
}
