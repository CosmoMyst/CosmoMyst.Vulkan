using System;
using System.Runtime.InteropServices;

using SharpVk.Glfw;

using SharpVulkan;

using MathNet;
using MathNet.Numerics.LinearAlgebra;
using System.Collections.Generic;
using System.Text;

namespace Vulkan.Engine
{
    public class Program
    {
        private const int WindowWidth = 800;
        private const int WindowHeight = 600;

        private const bool enableValidationLayers = true;

        private WindowHandle window;
        
        private Instance instance;

        private List<string> availableLayerNames = new List<string> ();

        private DebugReportCallback debugReportCallback;
        private DebugReportCallbackDelegate debugReport;

        private static void Main ()
        {
            Program program = new Program ();

            try
            {
                program.Run ();
            }
            catch (Exception e)
            {
                Console.WriteLine (e);
            }
        }

        public void Run ()
        {
            InitWindow ();
            InitVulkan ();
            MainLoop ();
            Cleanup ();
        }

        private void InitWindow ()
        {
            Glfw3.Init ();

            // Glfw3.WindowHint (Glfw3., false);
            // Glfw3.WindowHint (Glfw3.Hint.Resizable, false);
            // TODO: No clue how to do this with my GLFW bindings

            window = Glfw3.CreateWindow (WindowWidth, WindowHeight, "Vulkan", IntPtr.Zero, IntPtr.Zero);
        }

        private void InitVulkan ()
        {
            CreateInstance ();
        }

        private void MainLoop ()
        {
            while (!Glfw3.WindowShouldClose (window))
                Glfw3.PollEvents ();
        }

        private unsafe void Cleanup ()
        {
            // Glfw3.Destroy (window);
            // TODO: No clue how to do this

            if (debugReportCallback != DebugReportCallback.Null)
            {
                var destroyDebugReportCallbackName = Encoding.ASCII.GetBytes("vkDestroyDebugReportCallbackEXT");
                fixed (byte* destroyDebugReportCallbackNamePointer = &destroyDebugReportCallbackName[0])
                {
                    var destroyDebugReportCallback = Marshal.GetDelegateForFunctionPointer<DestroyDebugReportCallbackDelegate>(instance.GetProcAddress(destroyDebugReportCallbackNamePointer));
                    destroyDebugReportCallback(instance, debugReportCallback, null);
                }
            }

            instance.Destroy ();

            Glfw3.Terminate ();
        }

        private unsafe void CreateInstance ()
        {
            if (enableValidationLayers && !CheckValidationLayerSupport ())
                throw new Exception ("Validation layers requested, but not available!");

            IntPtr appName = Marshal.StringToHGlobalUni("Vulkan");
            IntPtr engineName = Marshal.StringToHGlobalUni("No Engine");

            string[] extensions = Glfw3.GetRequiredInstanceExtensions();

            IntPtr[] enabledExtensionNames = new IntPtr[extensions.Length + 1];

            IntPtr[] availableLayers = new IntPtr [availableLayerNames.Count];

            try
            {
                LayerProperties[] availableLayerProperties = SharpVulkan.Vulkan.InstanceLayerProperties;
                for (int i = 0; i < availableLayers.Length; i++)
                {
                    fixed (void* propertyNamePointer = &availableLayerProperties [i].LayerName.Value0)
                    {
                        string propertyLayerName = Marshal.PtrToStringAnsi(new IntPtr(propertyNamePointer));

                        availableLayers [i] = Marshal.StringToHGlobalAnsi (propertyLayerName);
                    }
                }

                ApplicationInfo appInfo = new ApplicationInfo
                {
                    StructureType = StructureType.ApplicationInfo,
                    ApplicationName = appName,
                    ApplicationVersion = 1,
                    EngineName = engineName,
                    EngineVersion = 1,
                    ApiVersion = SharpVulkan.Vulkan.ApiVersion
                };

                for (int i = 0; i < extensions.Length; i++)
                    enabledExtensionNames[i] = Marshal.StringToHGlobalAnsi(extensions[i]);

                enabledExtensionNames [enabledExtensionNames.Length - 1] = Marshal.StringToHGlobalAnsi ("VK_EXT_debug_report");

                fixed (void* enabledExtensionNamesPointer = &enabledExtensionNames[0])
                fixed (void* enabledLayerNamesPointer = &availableLayers [0])
                {
                    InstanceCreateInfo createInfo = new InstanceCreateInfo
                    {
                        StructureType = StructureType.InstanceCreateInfo,
                        ApplicationInfo = new IntPtr(&appInfo),
                        EnabledExtensionCount = (uint)enabledExtensionNames.Length,
                        EnabledExtensionNames = new IntPtr(enabledExtensionNamesPointer),
                    };

                    if (enableValidationLayers)
                    {
                        createInfo.EnabledLayerCount = (uint) availableLayers.Length;
                        createInfo.EnabledLayerNames = new IntPtr (enabledLayerNamesPointer);
                    } 

                    instance = SharpVulkan.Vulkan.CreateInstance(ref createInfo);
                }

                if (enableValidationLayers)
                {
                    byte [] createDebugReportCallbackName = Encoding.ASCII.GetBytes("vkCreateDebugReportCallbackEXT");
                    fixed (byte* createDebugReportCallbackNamePointer = &createDebugReportCallbackName[0])
                    {
                        CreateDebugReportCallbackDelegate createDebugReportCallback = Marshal.GetDelegateForFunctionPointer<CreateDebugReportCallbackDelegate>(instance.GetProcAddress(createDebugReportCallbackNamePointer));

                        debugReport = DebugReport;
                        DebugReportCallbackCreateInfo createInfo = new DebugReportCallbackCreateInfo
                        {
                            StructureType = StructureType.DebugReportCallbackCreateInfo,
                            Flags = (uint)(DebugReportFlags.Error | DebugReportFlags.Warning | DebugReportFlags.PerformanceWarning),
                            Callback = Marshal.GetFunctionPointerForDelegate(debugReport)
                        };
                        createDebugReportCallback(instance, ref createInfo, null, out debugReportCallback);
                    }
                }
            }
            finally
            {
                Marshal.FreeHGlobal(appName);
                Marshal.FreeHGlobal(engineName);

                for (int i = 0; i < enabledExtensionNames.Length; i++)
                    Marshal.FreeHGlobal(enabledExtensionNames[i]);

                foreach (IntPtr i in availableLayers)
                    Marshal.FreeHGlobal (i);
            }
        }

        private static RawBool DebugReport(DebugReportFlags flags, DebugReportObjectType objectType, ulong @object, PointerSize location, int messageCode, string layerPrefix, string message, IntPtr userData)
        {
            Console.WriteLine($"{flags}: {message} ([{messageCode}] {layerPrefix})");
            return true;
        }

        private unsafe bool CheckValidationLayerSupport ()
        {
            uint layerCount;
            LayerProperties [] availableLayers = SharpVulkan.Vulkan.InstanceLayerProperties;
            layerCount = (uint) availableLayers.Length;

            IntPtr [] validationLayers = new []
            {
                Marshal.StringToHGlobalAnsi("VK_LAYER_LUNARG_standard_validation")
            };

            try
            {
                foreach (var layerProperties in availableLayers)
                {
                    void* propertyNamePointer = &layerProperties.LayerName.Value0;

                    string propertyLayerName = Marshal.PtrToStringAnsi(new IntPtr(propertyNamePointer));

                    availableLayerNames.Add (propertyLayerName);
                }

                foreach (IntPtr ptr in validationLayers)
                {
                    bool layerFound = false;

                    string layerName = Marshal.PtrToStringUTF8 (ptr);

                    foreach (string propertyName in availableLayerNames)
                    {
                        if (string.Compare (layerName, propertyName) == 0)
                        {
                            layerFound = true;
                            break;
                        }
                    }

                    if (layerFound == false)
                        return false;
                }
            }
            finally
            {
                foreach (IntPtr s in validationLayers)
                    Marshal.FreeHGlobal (s);
            }

            return true;
        }

        [UnmanagedFunctionPointer(CallingConvention.StdCall, CharSet = CharSet.Ansi)]
        private unsafe delegate RawBool DebugReportCallbackDelegate(DebugReportFlags flags, DebugReportObjectType objectType, ulong @object, PointerSize location, int messageCode, string layerPrefix, string message, IntPtr userData);

        [UnmanagedFunctionPointer(CallingConvention.StdCall)]
        private unsafe delegate Result CreateDebugReportCallbackDelegate(Instance instance, ref DebugReportCallbackCreateInfo createInfo, AllocationCallbacks* allocator, out DebugReportCallback callback);

        [UnmanagedFunctionPointer(CallingConvention.StdCall)]
        private unsafe delegate Result DestroyDebugReportCallbackDelegate(Instance instance, DebugReportCallback debugReportCallback, AllocationCallbacks* allocator);
    }
}
