using System.Runtime.InteropServices;

namespace SharpVk.Glfw
{
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    public delegate void WindowSizeDelegate(WindowHandle window, int width, int height);
}