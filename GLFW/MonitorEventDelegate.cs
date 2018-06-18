using System.Runtime.InteropServices;

namespace SharpVk.Glfw
{
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    public delegate void MonitorEventDelegate(MonitorHandle monitor, int eventStatus);
}
