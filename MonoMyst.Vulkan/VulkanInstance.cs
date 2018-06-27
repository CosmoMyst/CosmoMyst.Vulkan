using System;
using System.Linq;
using MonoMyst.Vulkan.Utilities;
using System.Runtime.InteropServices;

using SharpVulkan;

using Vk = SharpVulkan;
using Version = SharpVulkan.Version;

using Glfw3 = MonoMyst.Glfw.Glfw;

namespace MonoMyst.Vulkan
{
    public unsafe class VulkanInstance : IDisposable
    {
        private readonly Instance instance;

        private readonly ExtensionProperties [] availableExtensions;
        private readonly string [] glfwExtensions;

        public VulkanInstance (string appName)
        {
            ApplicationInfo appInfo = new ApplicationInfo
            {
                StructureType = StructureType.ApplicationInfo,
                ApplicationName = Marshal.StringToHGlobalAnsi (appName),
                ApplicationVersion = new Version (0, 1, 1),
                EngineName = Marshal.StringToHGlobalAnsi ("MonoMyst"),
                EngineVersion = new Version (0, 1, 1),
                ApiVersion = Vk.Vulkan.ApiVersion
            };

            glfwExtensions = Glfw3.GetRequiredInstanceExtensions ();
            IntPtr* glfwExtensionsPointer = stackalloc IntPtr [glfwExtensions.Length];
            for (int i = 0; i < glfwExtensions.Length; i++)
                glfwExtensionsPointer [i] = Marshal.StringToHGlobalAnsi (glfwExtensions [i]);

            InstanceCreateInfo createInfo = new InstanceCreateInfo
            {
                StructureType = StructureType.InstanceCreateInfo,
                ApplicationInfo = new IntPtr (&appInfo),
                EnabledExtensionCount = (uint) glfwExtensions.Length,
                EnabledExtensionNames = new IntPtr (glfwExtensionsPointer),
                EnabledLayerCount = 0
            };

            instance = Vk.Vulkan.CreateInstance (ref createInfo);

            availableExtensions = Vk.Vulkan.GetInstanceExtensionProperties ();

            Marshal.FreeHGlobal (appInfo.ApplicationName);
            Marshal.FreeHGlobal (appInfo.EngineName);
            for (int i = 0; i < glfwExtensions.Length; i++)
                Marshal.FreeHGlobal (glfwExtensionsPointer [i]);
        }

        public void PrintAvailableExtensions ()
        {
            Console.WriteLine ("Available extensions:");
            foreach (ExtensionProperties e in availableExtensions)
                Console.WriteLine ($"\t{VulkanUtilities.ExtensionPropertiesToString (e)}");
        }

        public void PrintGlfwExtensions ()
        {
            Console.WriteLine ("Glfw extensions:");
            foreach (string e in glfwExtensions)
                Console.WriteLine ($"\t{e}");
        }

        public bool CheckRequiredExtensionsPresent ()
        {
            foreach (string g in glfwExtensions)
            {
                string [] properties = VulkanUtilities.ExtensionPropertiesToString (availableExtensions);

                if (properties.Contains (g) == false) return false;
            }

            return true;
        }

        public void Dispose ()
        {
            instance.Destroy ();
        }
    }
}
