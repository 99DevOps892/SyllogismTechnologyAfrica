public static class Cth1
{
    public static string Get(string target)
    {
        IntPtr p;
        if (!CredReadW(target, 1, 0, out p)) return null;
        try
        {
            var c = (C)Marshal.PtrToStructure(p, typeof(C));
            var b = new byte[c.N];
            Marshal.Copy(c.B, b, 0, c.N);
            return Encoding.UTF8.GetString(b);
        }
        finally { CredFree(p); }
    }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct C { public uint F; public uint T; public IntPtr Tn; public IntPtr R; public long W; public int N; public IntPtr B; public uint P; public int Ac; public IntPtr At; public IntPtr Ps; public IntPtr Ti; public IntPtr U; }
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, EntryPoint = "CredReadW")] static extern bool CredReadW(string t, int type, int flags, out IntPtr p);
    [DllImport("advapi32.dll")] static extern bool CredFree(IntPtr p);
}
