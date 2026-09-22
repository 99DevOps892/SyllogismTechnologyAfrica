$src = @

using System;

using System.Text;

using System.Runtime.InteropServices;

public static class VTK {

  [DllImport("advapi32.dll", CharSet=CharSet.Unicode, EntryPoint="CredReadW")]

  static extern bool CredReadW(string t, int ty, int fl, out IntPtr p);

  [DllImport("advapi32.dll")] static extern bool CredFree(IntPtr p);

  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]

  struct C { public uint A; public uint B; public IntPtr Cn; public IntPtr Cm; public long W; public int N; public IntPtr Blob; public uint P; public int Ac; public IntPtr At; public IntPtr Ta; public IntPtr U; }

  public static string Read() {

    IntPtr p;

    if (!CredReadW("Supabase CLI:supabase", 1, 0, out p)) return null;

    try { var c=(C)Marshal.PtrToStructure(p, typeof(C)); var b=new byte[c.N]; Marshal.Copy(c.Blob,b,0,c.N); return Encoding.UTF8.GetString(b); }

    finally { CredFree(p); }

  }

}
Add-Type -TypeDefinition @'
using System;using System.Text;using System.Runtime.InteropServices;
public static class VTK2 {
  [DllImport("advapi32.dll", CharSet=CharSet.Unicode, EntryPoint="CredReadW")] static extern bool CredReadW(string t,int ty,int fl,out IntPtr p);
  [DllImport("advapi32.dll")] static extern bool CredFree(IntPtr p);
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
  struct CR { public uint A; public uint B; public IntPtr Cn; public IntPtr Cm; public long W; public int N; public IntPtr Blob; public uint P; public int Ac; public IntPtr At; public IntPtr Ta; public IntPtr U; }
  public static string Read(){ IntPtr p; if(!CredReadW("Supabase CLI:supabase",1,0,out p)) return null; try{var c=(CR)Marshal.PtrToStructure(p,typeof(CR)); var b=new byte[c.N]; Marshal.Copy(c.Blob,b,0,c.N); return Encoding.UTF8.GetString(b);}finally{CredFree(p);} }
}
'@
