using System;
using System.Runtime.InteropServices;

using SharpVulkan;

namespace SharpVk.Glfw
{
    public unsafe static class Glfw3
    {
        public const string GlfwDll = "glfw3.dll";
        //public const string GlfwDll = "libglfw.so";

        [DllImport(GlfwDll, CallingConvention = CallingConvention.Cdecl, EntryPoint = "glfwInit")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool Init();

        [DllImport(GlfwDll, CallingConvention = CallingConvention.Cdecl, EntryPoint = "glfwTerminate")]
        public static extern void Terminate();

        [DllImport(GlfwDll, CallingConvention = CallingConvention.Cdecl, EntryPoint = "glfwDestroyWindow")]
        public static extern void DestroyWindow (WindowHandle window);

        [DllImport(GlfwDll, CallingConvention = CallingConvention.Cdecl, EntryPoint = "glfwGetVersion")]
        public static extern void GetVersion(out int major, out int minor, out int rev);

        [DllImport(GlfwDll, CallingConvention = CallingConvention.Cdecl, EntryPoint = "glfwCreateWindow")]
        public static extern WindowHandle CreateWindow(int width, int height, [MarshalAs(UnmanagedType.LPStr)] string title, IntPtr monitor, IntPtr share);

        [DllImport(GlfwDll, CallingConvention = CallingConvention.Cdecl, EntryPoint = "glfwPollEvents")]
        public static extern void PollEvents();

        [DllImport(GlfwDll, CallingConvention = CallingConvention.Cdecl, EntryPoint = "glfwWindowHint")]
        public static extern void WindowHint(int target, int hint);

        [DllImport(GlfwDll, CallingConvention = CallingConvention.Cdecl, EntryPoint = "glfwWindowShouldClose")]
        public static extern bool WindowShouldClose(WindowHandle window);

        [DllImport(GlfwDll, CallingConvention = CallingConvention.Cdecl, EntryPoint = "glfwCreateWindowSurface")]
        public unsafe static extern Result glfwCreateWindowSurface (Instance instance, WindowHandle window, AllocationCallbacks* pAllocator, Surface* surface);

        public unsafe static Surface CreateWindowSurface (Instance instance, WindowHandle window, AllocationCallbacks* pAllocator = null)
        {
            Surface surface;
            
            glfwCreateWindowSurface (instance, window, null, &surface);

            return surface;
        }

        [DllImport(GlfwDll, CallingConvention = CallingConvention.Cdecl, EntryPoint = "glfwGetRequiredInstanceExtensions")]
        public static extern byte** GetRequiredInstanceExtensions(out int count);

        [DllImport(GlfwDll, CallingConvention = CallingConvention.Cdecl, EntryPoint = "glfwSetWindowSizeCallback")]
        public static extern WindowSizeDelegate SetWindowSizeCallback(WindowHandle window, WindowSizeDelegate callback);

        [DllImport(GlfwDll, CallingConvention = CallingConvention.Cdecl, EntryPoint = "glfwSetErrorCallback")]
        public static extern ErrorDelegate SetErrorCallback(ErrorDelegate callback);

        [DllImport(GlfwDll, CallingConvention = CallingConvention.Cdecl, EntryPoint = "glfwGetMonitors")]
        public static extern MonitorHandle* GetMonitors(out int count);

        [DllImport(GlfwDll, CallingConvention = CallingConvention.Cdecl, EntryPoint = "glfwGetPrimaryMonitor")]
        public static extern MonitorHandle GetPrimaryMonitor();

        [DllImport(GlfwDll, CallingConvention = CallingConvention.Cdecl, EntryPoint = "glfwGetMonitorPos")]
        public static extern void GetMonitorPos(MonitorHandle monitor, out int xPos, out int yPos);

        [DllImport(GlfwDll, CallingConvention = CallingConvention.Cdecl, EntryPoint = "glfwGetMonitorPhysicalSize")]
        public static extern void GetMonitorPhysicalSize(MonitorHandle monitor, out int widthMm, out int heightMm);

        [DllImport(GlfwDll, CallingConvention = CallingConvention.Cdecl, EntryPoint = "glfwGetMonitorName")]
        [return: MarshalAs(UnmanagedType.LPStr)]
        public static extern string GetMonitorName(MonitorHandle monitor);

        [DllImport(GlfwDll, CallingConvention = CallingConvention.Cdecl, EntryPoint = "glfwSetMonitorCallback")]
        public static extern MonitorEventDelegate SetMonitorCallback(MonitorEventDelegate callback);

        [DllImport(GlfwDll, CallingConvention = CallingConvention.Cdecl, EntryPoint = "glfwGetVideoModes")]
        public static extern VideoMode* GetVideoModes(MonitorHandle monitor, out int count);

        [DllImport(GlfwDll, CallingConvention = CallingConvention.Cdecl, EntryPoint = "glfwGetVideoMode")]
        public static extern VideoModePointer GetVideoMode(MonitorHandle monitor);

        [DllImport(GlfwDll, CallingConvention = CallingConvention.Cdecl, EntryPoint = "glfwSetGamma")]
        public static extern void SetGamma(MonitorHandle monitor, float gamma);

        public static string[] GetRequiredInstanceExtensions()
        {
            byte** namePointer = GetRequiredInstanceExtensions(out int count);

            var result = new string[count];

            for (int nameIndex = 0; nameIndex < count; nameIndex++)
            {
                result[nameIndex] = Marshal.PtrToStringAnsi(new IntPtr(namePointer[nameIndex]));
            }

            return result;
        }

        public static MonitorHandle[] GetMonitors()
        {
            MonitorHandle* monitorPointer = GetMonitors(out int count);

            var result = new MonitorHandle[count];

            for (int i = 0; i < count; i++)
            {
                result[i] = monitorPointer[i];
            }

            return result;
        }

        public static VideoMode[] GetVideoModes(MonitorHandle monitor)
        {
            VideoMode* videoModePointer = GetVideoModes(monitor, out int count);

            var result = new VideoMode[count];

            for (int i = 0; i < count; i++)
            {
                result[i] = videoModePointer[i];
            }

            return result;
        }

        public static System.Version GetVersion()
        {
            GetVersion(out int major, out int minor, out int revision);

            return new System.Version(major, minor, revision);
        }
    }
}
