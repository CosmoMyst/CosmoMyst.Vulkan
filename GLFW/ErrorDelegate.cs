using System.Runtime.InteropServices;

namespace SharpVk.Glfw
{
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    public delegate void ErrorDelegate(int error, [MarshalAs(UnmanagedType.LPStr)] string description);
}
