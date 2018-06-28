using System;
using System.Runtime.InteropServices;

using SharpVulkan;

namespace MonoMyst.Vulkan.Utilities
{
    public unsafe class VulkanUtilities
    {
        public static void CallFunctionOnInstance<TFunctionDel> (Instance instance, string functionName, Action<TFunctionDel> call)
        {
            IntPtr functionNamePointer = Marshal.StringToHGlobalAnsi (functionName);
            IntPtr functionPointer = instance.GetProcAddress ((byte*) functionNamePointer);
            if (functionPointer == IntPtr.Zero)
                throw new Exception ($"Failed to find function {functionName}");
            else
            {
                TFunctionDel function = Marshal.GetDelegateForFunctionPointer<TFunctionDel> (functionPointer);
                call (function);
            }

            Marshal.FreeHGlobal (functionNamePointer);
        }

        public static string ExtensionPropertiesToString (ExtensionProperties e)
        {
            void* namePointer = &e.ExtensionName.Value0;
            return Marshal.PtrToStringAnsi (new IntPtr (namePointer));
        }

        public static string [] ExtensionPropertiesToString (ExtensionProperties [] e)
        {
            string [] result = new string [e.Length];
            for (int i = 0; i < e.Length; i++)
                result [i] = ExtensionPropertiesToString (e [i]);

            return result;
        }

        public static string LayerPropertiesToString (LayerProperties l)
        {
            void* namePointer = &l.LayerName.Value0;
            return Marshal.PtrToStringAnsi (new IntPtr (namePointer));
        }

        public static string [] LayerPropertiesToString (LayerProperties [] l)
        {
            string [] result = new string [l.Length];
            for (int i = 0; i < l.Length; i++)
                result [i] = LayerPropertiesToString (l [i]);

            return result;
        }
    }
}
