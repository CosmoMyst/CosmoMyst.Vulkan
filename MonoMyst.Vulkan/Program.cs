using System;
using System.Linq;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;

using SharpVk.Glfw;

using SharpVulkan;

namespace MonoMyst.Vulkan
{
    public class Program
    {
        private const int WindowWidth = 800;
        private const int WindowHeight = 600;

        private const bool enableValidationLayers = true;

        private WindowHandle window;
        
        private Instance instance;
        private PhysicalDevice physicalDevice;
        private Device device;

        private Swapchain swapChain;
        private List<Image> swapChainImages = new List<Image> ();
        private Format swapChainImageFormat;
        private Extent2D swapChainExtent;

        private Queue graphicsQueue;
        private Queue presentQueue;

        private List<string> availableLayerNames = new List<string> ();

        private List<string> deviceExtensions = new List<string>
        {
            "VK_KHR_swapchain"
        };

        private DebugReportCallback debugReportCallback;
        private DebugReportCallbackDelegate debugReport;

        private Surface surface;

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

            window = Glfw3.CreateWindow (WindowWidth, WindowHeight, "MonoMyst.Vulkan", IntPtr.Zero, IntPtr.Zero);
        }

        private void InitVulkan ()
        {
            CreateInstance ();

            CreateSurface ();

            PickPhysicalDevice ();

            CreateLogicalDevice ();
        
            CreateSwapChain ();
        }

        private unsafe void CreateSurface ()
        {
            surface = Glfw3.CreateWindowSurface (instance, window);
        }

        private void PickPhysicalDevice ()
        {
            PhysicalDevice [] devices = instance.PhysicalDevices;

            if (devices.Length == 0)
                throw new Exception ("No GPUs with Vulkan support found.");

            foreach (PhysicalDevice d in devices)
            {
                if (IsDeviceSuitable (d))
                {
                    physicalDevice = d;
                    break;
                }
            }

            if (physicalDevice == null)
                throw new Exception ("Failed to find a suitable GPU.");
        }

        private unsafe void CreateLogicalDevice ()
        {
            QueueFamilyIndices indices = FindQueueFamilies (physicalDevice);

            List<DeviceQueueCreateInfo> queueCreateInfos = new List<DeviceQueueCreateInfo> ();
            SortedSet<int> uniqueQueueFamilies = new SortedSet<int>
            {
                indices.GraphicsFamily,
                indices.PresentFamily
            };

            float queuePriority = 1.0f;

            foreach (int queueFamily in uniqueQueueFamilies)
            {
                DeviceQueueCreateInfo queueCreateInfo = new DeviceQueueCreateInfo
                {
                    StructureType = StructureType.DeviceQueueCreateInfo,
                    QueueFamilyIndex = (uint) queueFamily,
                    QueueCount = 1,
                    QueuePriorities = new IntPtr (&queuePriority)
                };

                queueCreateInfos.Add (queueCreateInfo);
            }

            IntPtr[] availableLayers = new IntPtr[availableLayerNames.Count];

            IntPtr [] extensionNames = new IntPtr [deviceExtensions.Count];

            try
            {
                LayerProperties[] availableLayerProperties = SharpVulkan.Vulkan.InstanceLayerProperties;
                for (int i = 0; i < availableLayers.Length; i++)
                {
                    fixed (void* propertyNamePointer = &availableLayerProperties[i].LayerName.Value0)
                    {
                        string propertyLayerName = Marshal.PtrToStringAnsi(new IntPtr(propertyNamePointer));

                        availableLayers[i] = Marshal.StringToHGlobalAnsi(propertyLayerName);
                    }
                }

                PhysicalDeviceFeatures deviceFeatures = new PhysicalDeviceFeatures ();

                IntPtr result = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(DeviceQueueCreateInfo)) * queueCreateInfos.Count);
                IntPtr c = new IntPtr(result.ToInt32());
                for (int i = 0; i < queueCreateInfos.Count; i++)
                {
                    Marshal.StructureToPtr(queueCreateInfos[i], c, true);
                    c = new IntPtr(c.ToInt32() + Marshal.SizeOf(typeof(DeviceQueueCreateInfo)));
                }

                DeviceCreateInfo createInfo = new DeviceCreateInfo
                {
                    StructureType = StructureType.DeviceCreateInfo,
                    QueueCreateInfos = result,
                    QueueCreateInfoCount = (uint) queueCreateInfos.Count,
                    EnabledFeatures = new IntPtr (&deviceFeatures)
                };

                createInfo.EnabledExtensionCount = (uint) deviceExtensions.Count;
                
                for (int i = 0; i < deviceExtensions.Count; i++)
                    extensionNames [i] = Marshal.StringToHGlobalAnsi (deviceExtensions [i]);

                fixed (void* extensionNamesPointer = &extensionNames[0])                
                createInfo.EnabledExtensionNames = new IntPtr (extensionNamesPointer);

                fixed (void* layersPointer = &availableLayers[0])
                if (enableValidationLayers)
                {
                    createInfo.EnabledLayerCount = (uint) availableLayers.Length;
                    createInfo.EnabledLayerNames = new IntPtr (layersPointer);
                }

                device = physicalDevice.CreateDevice (ref createInfo);
                graphicsQueue = device.GetQueue ((uint) indices.GraphicsFamily, 0);
                presentQueue = device.GetQueue ((uint) indices.PresentFamily, 0);
            }
            finally
            {
                foreach (IntPtr i in availableLayers)
                    Marshal.FreeHGlobal(i);

                foreach (IntPtr i in extensionNames)
                    Marshal.FreeHGlobal (i);
            }
        }

        private bool IsDeviceSuitable (PhysicalDevice device)
        {
            QueueFamilyIndices indices = FindQueueFamilies (device);

            bool extensionsSupported = CheckDeviceExtensionSupport (device);

            bool swapChainAdequate = false;

            if (extensionsSupported)
            {
                SwapChainSupportDetails swapChainSupport = QuerySwapChainSupport (device);
                swapChainAdequate = !(swapChainSupport.Formats.Count == 0) && !(swapChainSupport.PresentModes.Count == 0);
            }

            return indices.IsComplete () && extensionsSupported && swapChainAdequate;
        }

        private unsafe bool CheckDeviceExtensionSupport (PhysicalDevice device)
        {
            SortedSet<string> requiredExtensions = new SortedSet<string> ();
            
            foreach (string ext in deviceExtensions)
                requiredExtensions.Add (ext);

            foreach (ExtensionProperties extension in device.GetDeviceExtensionProperties ())
            {
                void* extensionPointer = &extension.ExtensionName.Value0;

                string extensionName = Marshal.PtrToStringAnsi (new IntPtr (extensionPointer));

                requiredExtensions.Remove (extensionName);
            }

            return requiredExtensions.Count == 0;
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

            device.DestroySwapchain (swapChain);
            device.Destroy ();
            instance.DestroySurface (surface);
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

        private QueueFamilyIndices FindQueueFamilies (PhysicalDevice device)
        {
            QueueFamilyIndices indices = new QueueFamilyIndices ();

            int i = 0;
            foreach (QueueFamilyProperties queueFamily in device.QueueFamilyProperties)
            {
                if (queueFamily.QueueCount > 0 && (queueFamily.QueueFlags & QueueFlags.Graphics) != 0)
                    indices.GraphicsFamily = i;

                RawBool presentSupport = device.GetSurfaceSupport ((uint) i, surface);

                if (queueFamily.QueueCount > 0 && presentSupport)
                    indices.PresentFamily = i;

                if (indices.IsComplete ())
                    break;

                i++;
            }

            return indices;
        }

        private SwapChainSupportDetails QuerySwapChainSupport (PhysicalDevice device)
        {
            SwapChainSupportDetails details = new SwapChainSupportDetails ();

            device.GetSurfaceCapabilities (surface, out details.Capabilities);

            details.Formats = device.GetSurfaceFormats (surface).ToList ();

            details.PresentModes = device.GetSurfacePresentModes (surface).ToList ();

            return details;
        }

        private SurfaceFormat ChooseSwapSurfaceFormat (List<SurfaceFormat> availableFormats)
        {
            if (availableFormats.Count == 1 && availableFormats [0].Format == Format.Undefined)
                return new SurfaceFormat
                {
                    Format = Format.B8G8R8A8UNorm,
                    ColorSpace = ColorSpace.SRgbNonlinear
                };

            foreach (SurfaceFormat availableFormat in availableFormats)
                if (availableFormat.Format == Format.B8G8R8A8UNorm && availableFormat.ColorSpace == ColorSpace.SRgbNonlinear)
                    return availableFormat;

            return availableFormats [0];
        }

        private PresentMode ChooseSwapPresentMode (List<PresentMode> availablePresentModes)
        {
            PresentMode bestMode = PresentMode.Fifo;

            foreach (PresentMode presentMode in availablePresentModes)
                if (presentMode == PresentMode.Mailbox)
                    return presentMode;
                else if (presentMode == PresentMode.Immediate)
                    bestMode = presentMode;

            return bestMode;
        }

        private Extent2D ChooseSwapExtent (SurfaceCapabilities capabilities)
        {
            if (capabilities.CurrentExtent.Width != uint.MaxValue)
                return capabilities.CurrentExtent;
            else
            {
                Extent2D actualExtent = new Extent2D
                {
                    Width = WindowWidth,
                    Height = WindowHeight
                };

                actualExtent.Width = Math.Max (capabilities.MinImageExtent.Width, Math.Min (capabilities.MaxImageExtent.Width, actualExtent.Width));
                actualExtent.Height = Math.Max (capabilities.MinImageExtent.Height, Math.Min (capabilities.MaxImageExtent.Height, actualExtent.Height));

                return actualExtent;
            }
        }

        private unsafe void CreateSwapChain ()
        {
            SwapChainSupportDetails swapChainSupport = QuerySwapChainSupport (physicalDevice);

            SurfaceFormat surfaceFormat = ChooseSwapSurfaceFormat (swapChainSupport.Formats);
            PresentMode presentMode = ChooseSwapPresentMode (swapChainSupport.PresentModes);
            Extent2D extent = ChooseSwapExtent (swapChainSupport.Capabilities);

            uint imageCount = swapChainSupport.Capabilities.MinImageCount + 1;
            if (swapChainSupport.Capabilities.MaxImageCount > 0 && imageCount > swapChainSupport.Capabilities.MaxImageCount)
                imageCount = swapChainSupport.Capabilities.MaxImageCount;

            SwapchainCreateInfo createInfo = new SwapchainCreateInfo
            {
                StructureType = StructureType.SwapchainCreateInfo,
                Surface = surface,
                MinImageCount = imageCount,
                ImageFormat = surfaceFormat.Format,
                ImageColorSpace = surfaceFormat.ColorSpace,
                ImageExtent = extent,
                ImageArrayLayers = 1,
                ImageUsage = ImageUsageFlags.ColorAttachment
            };

            QueueFamilyIndices indices = FindQueueFamilies (physicalDevice);

            uint [] queueFamilyIndices = new uint []
            {
                (uint) indices.GraphicsFamily,
                (uint) indices.PresentFamily
            };

            fixed (void* queueFamilyIndicesPointer = queueFamilyIndices)
            if (indices.GraphicsFamily != indices.PresentFamily)
            {
                createInfo.ImageSharingMode = SharingMode.Concurrent;
                createInfo.QueueFamilyIndexCount = 2;
                createInfo.QueueFamilyIndices = new IntPtr (queueFamilyIndicesPointer);
            }
            else
            {
                createInfo.ImageSharingMode = SharingMode.Exclusive;
                createInfo.QueueFamilyIndexCount = 0;
                createInfo.QueueFamilyIndices = new IntPtr (null);
            }

            createInfo.PreTransform = swapChainSupport.Capabilities.CurrentTransform;
            createInfo.CompositeAlpha = CompositeAlphaFlags.Opaque;
            createInfo.PresentMode = presentMode;
            createInfo.Clipped = true;
            createInfo.OldSwapchain = Swapchain.Null;

            swapChain = device.CreateSwapchain (ref createInfo);

            swapChainImages = device.GetSwapchainImages (swapChain).ToList ();
            swapChainImageFormat = surfaceFormat.Format;
            swapChainExtent = extent;
        }

        class QueueFamilyIndices
        {
            public int GraphicsFamily = -1;
            public int PresentFamily = -1;

            public bool IsComplete ()
            {
                return GraphicsFamily >= 0 && PresentFamily >= 0;
            }
        }

        class SwapChainSupportDetails
        {
            public SurfaceCapabilities Capabilities;
            public List<SurfaceFormat> Formats;
            public List<PresentMode> PresentModes; 
        }

        [UnmanagedFunctionPointer(CallingConvention.StdCall, CharSet = CharSet.Ansi)]
        private unsafe delegate RawBool DebugReportCallbackDelegate(DebugReportFlags flags, DebugReportObjectType objectType, ulong @object, PointerSize location, int messageCode, string layerPrefix, string message, IntPtr userData);

        [UnmanagedFunctionPointer(CallingConvention.StdCall)]
        private unsafe delegate Result CreateDebugReportCallbackDelegate(Instance instance, ref DebugReportCallbackCreateInfo createInfo, AllocationCallbacks* allocator, out DebugReportCallback callback);

        [UnmanagedFunctionPointer(CallingConvention.StdCall)]
        private unsafe delegate Result DestroyDebugReportCallbackDelegate(Instance instance, DebugReportCallback debugReportCallback, AllocationCallbacks* allocator);
    }
}
