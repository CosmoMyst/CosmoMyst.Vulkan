using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

using SharpVulkan;

using MonoMyst.Vulkan.Utilities;

using Vk = SharpVulkan;
using Version = SharpVulkan.Version;

using Glfw3 = MonoMyst.Glfw.Glfw;

using static MonoMyst.Glfw.Glfw;

namespace MonoMyst.Vulkan
{
    public unsafe class VulkanInstance : IDisposable
    {
        private Instance instance;

        private readonly ExtensionProperties [] availableExtensions;

        private readonly bool enableDebug;

        private DebugReportCallback debugReportCallback;
        private DebugReportCallbackDelegate debugReportCallbackFunctionReference;

        public VulkanInstance (string appName, bool enableDebug = false)
        {
            this.enableDebug = enableDebug;

            ApplicationInfo appInfo = new ApplicationInfo
            {
                StructureType = StructureType.ApplicationInfo,
                ApplicationName = Marshal.StringToHGlobalAnsi (appName),
                ApplicationVersion = new Version (0, 1, 1),
                EngineName = Marshal.StringToHGlobalAnsi ("MonoMyst"),
                EngineVersion = new Version (0, 1, 1),
                ApiVersion = Vk.Vulkan.ApiVersion
            };

            string [] extensions = GetRequiredExtensions ();

            IntPtr* extensionsPointer = stackalloc IntPtr [extensions.Length];
            for (int i = 0; i < extensions.Length; i++)
                extensionsPointer [i] = Marshal.StringToHGlobalAnsi (extensions [i]);

            InstanceCreateInfo createInfo = new InstanceCreateInfo
            {
                StructureType = StructureType.InstanceCreateInfo,
                ApplicationInfo = new IntPtr (&appInfo),
                EnabledExtensionCount = (uint) extensions.Length,
                EnabledExtensionNames = new IntPtr (extensionsPointer),
                EnabledLayerCount = 0
            };

            IntPtr [] validationLayersPtr = null;
            if (enableDebug)
            {
                createInfo.EnabledLayerCount = (uint) Game.ValidationLayers.Length;

                validationLayersPtr = new IntPtr [Game.ValidationLayers.Length];
                for (int i = 0; i < Game.ValidationLayers.Length; i++)
                    validationLayersPtr [i] = Marshal.StringToHGlobalAnsi (Game.ValidationLayers [i]);

                fixed (void* validationLayersPointer = &validationLayersPtr [0])
                createInfo.EnabledLayerNames = new IntPtr (validationLayersPointer);
            }
            else
            {
                createInfo.EnabledLayerCount = 0;
            }

            instance = Vk.Vulkan.CreateInstance (ref createInfo);

            availableExtensions = Vk.Vulkan.GetInstanceExtensionProperties ();

            Marshal.FreeHGlobal (appInfo.ApplicationName);
            Marshal.FreeHGlobal (appInfo.EngineName);
            for (int i = 0; i < extensions.Length; i++)
                Marshal.FreeHGlobal (extensionsPointer [i]);

            if (enableDebug)
                foreach (IntPtr i in validationLayersPtr)
                    Marshal.FreeHGlobal (i);

            if (enableDebug)
                CreateDebugReport ();
        }

        public Device CreateDevice (Surface surface) => new Device (instance, surface, enableDebug);

        public Presenter CreatePresenter (Window window) => new Presenter (instance, window);

        private void CreateDebugReport ()
        {
            VulkanUtilities.CallFunctionOnInstance<CreateDebugReportDelegate> (instance, "vkCreateDebugReportCallbackEXT", (func) =>
            {
                debugReportCallbackFunctionReference = new DebugReportCallbackDelegate (Debug);
                DebugReportCallbackCreateInfo debugInfo = new DebugReportCallbackCreateInfo
                {
                    StructureType = StructureType.DebugReportCallbackCreateInfo,
                    Flags = (uint) (DebugReportFlags.Error | DebugReportFlags.Information | DebugReportFlags.PerformanceWarning | DebugReportFlags.Warning),
                    Callback = Marshal.GetFunctionPointerForDelegate (debugReportCallbackFunctionReference),
                    UserData = IntPtr.Zero
                };
                fixed (DebugReportCallback* debugReportCallbackPointer = &debugReportCallback)
                    func (instance, &debugInfo, null, debugReportCallbackPointer);
            });
        }

        private void Debug (DebugReportFlags flags, DebugReportObjectType objectType, ulong obj, PointerSize location, int code, string layerPrefix, string message, IntPtr userData)
        {
            switch (flags)
            {
                case DebugReportFlags.Error:
                    {
                        Logger.WriteLine (string.Format ("VULKAN ERROR ({0}): ", objectType) + message, ConsoleColor.Red);
                    } break;

                case DebugReportFlags.Warning:
                    {
                        Logger.WriteLine (string.Format ("VULKAN WARNING ({0}): ", objectType) + message, ConsoleColor.Yellow);
                    } break;

                case DebugReportFlags.PerformanceWarning:
                    {
                        Logger.WriteLine (string.Format ("VULKAN PERFORMANCE WARNING ({0}): ", objectType) + message, ConsoleColor.Green);
                    } break;

                // TODO: This information is annoying and generally just spams. Maybe make a switch to enable this *if really needed*
                //case DebugReportFlags.Information:
                //    {
                //        Logger.WriteLine (string.Format ("VULKAN INFORMATION ({0}): ", objectType) + message, ConsoleColor.Cyan);
                //    } break;

                case DebugReportFlags.Debug:
                    {
                        Logger.WriteLine (string.Format ("VULKAN DEBUG ({0}): ", objectType) + message, ConsoleColor.Gray);
                    } break;
            }
        }

        private string [] GetRequiredExtensions ()
        {
            List<string> extensions = new List<string> ();

            extensions.AddRange (Glfw3.GetRequiredInstanceExtensions ());

            extensions.Add (VulkanConstants.VK_DEBUG_REPORT);

            return extensions.ToArray ();
        }

        public void Dispose ()
        {
            if (enableDebug)
                VulkanUtilities.CallFunctionOnInstance<DestroyDebugReportDelegate> (instance, "vkDestroyDebugReportCallbackEXT", func => func (instance, debugReportCallback, null));

            instance.Destroy ();
        }

        private delegate void DebugReportCallbackDelegate (DebugReportFlags flags, DebugReportObjectType objectType, ulong obj, PointerSize location, int code, string layerPrefix, string message, IntPtr userData);
        private delegate void CreateDebugReportDelegate (Instance instance, DebugReportCallbackCreateInfo* createInfo, AllocationCallbacks* allocator, DebugReportCallback* callback);
        private delegate void DestroyDebugReportDelegate (Instance instance, DebugReportCallback callback, AllocationCallbacks* allocator);
    }
}
