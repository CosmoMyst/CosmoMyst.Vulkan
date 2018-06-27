using System;
using System.Runtime.InteropServices;

using SharpVulkan;

namespace MonoMyst.Vulkan.Utilities
{
    public unsafe class VulkanUtilities
    {
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
    }
}
