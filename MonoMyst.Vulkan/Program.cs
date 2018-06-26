using System;
using System.IO;
using System.Linq;
using System.Text;
using System.Diagnostics;
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
        private List<ImageView> swapChainImageViews = new List<ImageView> ();
        private Format swapChainImageFormat;
        private Extent2D swapChainExtent;

        private Framebuffer [] swapChainFramebuffers;

        private CommandPool commandPool;
        private CommandBuffer [] commandBuffers;

        private RenderPass renderPass;
        private PipelineLayout pipelineLayout;

        private Pipeline graphicsPipeline;

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

        public unsafe void Run ()
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

            CreateImageViews ();

            CreateRenderPass ();
        
            CreateGraphicsPipeline ();

            CreateFramebuffers ();

            CreateCommandPool ();

            CreateCommandBuffers ();
        }

        private unsafe void CreateCommandBuffers ()
        {
            commandBuffers = new CommandBuffer [swapChainFramebuffers.Length];

            CommandBufferAllocateInfo allocateInfo = new CommandBufferAllocateInfo
            {
                StructureType = StructureType.CommandBufferAllocateInfo,
                CommandPool = commandPool,
                Level = CommandBufferLevel.Primary,
                CommandBufferCount = (uint) commandBuffers.Length
            };

            device.AllocateCommandBuffers (ref allocateInfo, (CommandBuffer*) Marshal.UnsafeAddrOfPinnedArrayElement (commandBuffers, 0));

            for (int i = 0; i < commandBuffers.Length; i++)
            {
                CommandBufferBeginInfo beginInfo = new CommandBufferBeginInfo
                {
                    StructureType = StructureType.CommandBufferBeginInfo,
                    Flags = CommandBufferUsageFlags.SimultaneousUse,
                    InheritanceInfo = IntPtr.Zero
                };

                commandBuffers [i].Begin (ref beginInfo);

                ClearValue* clearValues = stackalloc ClearValue[2];
                clearValues[0].Color.Float32 = new ClearColorValue.Float32Array { Value0 = 0, Value1 = 0, Value2 = 0, Value3 = 1 };
                clearValues[1].DepthStencil.Depth = 1;

                RenderPassBeginInfo renderPassInfo = new RenderPassBeginInfo
                {
                    StructureType = StructureType.RenderPassBeginInfo,
                    RenderPass = renderPass,
                    Framebuffer = swapChainFramebuffers [i],
                    RenderArea = new Rect2D (new Offset2D (0, 0), swapChainExtent),
                    ClearValueCount = 2,
                    ClearValues = (IntPtr) clearValues
                };

                commandBuffers [i].BeginRenderPass (ref renderPassInfo, SubpassContents.Inline);

                commandBuffers [i].BindPipeline (PipelineBindPoint.Graphics, graphicsPipeline);

                commandBuffers [i].Draw (3, 1, 0, 0);

                commandBuffers [i].EndRenderPass ();

                commandBuffers [i].End ();
            }
        }

        private unsafe void CreateCommandPool ()
        {
            QueueFamilyIndices indices = FindQueueFamilies (physicalDevice);
        
            CommandPoolCreateInfo poolInfo = new CommandPoolCreateInfo
            {
                StructureType = StructureType.CommandPoolCreateInfo,
                QueueFamilyIndex = (uint) indices.GraphicsFamily,
                Flags = 0
            };

            commandPool = device.CreateCommandPool (ref poolInfo);
        }

        private unsafe void CreateFramebuffers ()
        {
            swapChainFramebuffers = new Framebuffer [swapChainImageViews.Count];

            for (int i = 0; i < swapChainImageViews.Count; i++)
            {
                ImageView* attachments = stackalloc ImageView [1];
                attachments [0] = swapChainImageViews [i];

                FramebufferCreateInfo framebufferInfo = new FramebufferCreateInfo
                {
                    StructureType = StructureType.FramebufferCreateInfo,
                    RenderPass = renderPass,
                    AttachmentCount = 1,
                    Attachments = (IntPtr) attachments,
                    Width = swapChainExtent.Width,
                    Height = swapChainExtent.Height,
                    Layers = 1
                };

                swapChainFramebuffers [i] = device.CreateFramebuffer (ref framebufferInfo);
            }
        }

        private unsafe void CreateRenderPass ()
        {
            AttachmentDescription colorAttachment = new AttachmentDescription
            {
                Format = swapChainImageFormat,
                Samples = SampleCountFlags.Sample1,
                LoadOperation = AttachmentLoadOperation.Clear,
                StoreOperation = AttachmentStoreOperation.Store,
                StencilLoadOperation = AttachmentLoadOperation.DontCare,
                StencilStoreOperation = AttachmentStoreOperation.DontCare,
                InitialLayout = ImageLayout.Undefined,
                FinalLayout = ImageLayout.PresentSource
            };

            AttachmentReference colorAttachmentRef = new AttachmentReference
            {
                Attachment = 0,
                Layout = ImageLayout.ColorAttachmentOptimal
            };

            SubpassDescription subpass = new SubpassDescription
            {
                PipelineBindPoint = PipelineBindPoint.Graphics,
                ColorAttachmentCount = 1,
                ColorAttachments = new IntPtr (&colorAttachmentRef)
            };

            RenderPassCreateInfo renderPassInfo = new RenderPassCreateInfo
            {
                StructureType = StructureType.RenderPassCreateInfo,
                AttachmentCount = 1,
                Attachments = new IntPtr (&colorAttachment),
                SubpassCount = 1,
                Subpasses = new IntPtr (&subpass)
            };

            renderPass = device.CreateRenderPass (ref renderPassInfo);
        }

        private unsafe void CreateGraphicsPipeline ()
        {
            ShaderModule vertShaderModule;
            ShaderModule fragShaderModule;

            vertShaderModule = CreateShaderModule (File.ReadAllBytes ($"{Environment.CurrentDirectory}/Shaders/vert.spv"));
            fragShaderModule = CreateShaderModule (File.ReadAllBytes ($"{Environment.CurrentDirectory}/Shaders/frag.spv"));

            byte [] entryPointName = System.Text.Encoding.UTF8.GetBytes("main\0");

            try
            {
                fixed (byte* entryPointNamePointer = &entryPointName[0])
                {
                    PipelineShaderStageCreateInfo vertShaderStageInfo = new PipelineShaderStageCreateInfo
                    {
                        StructureType = StructureType.PipelineShaderStageCreateInfo,
                        Stage = ShaderStageFlags.Vertex,
                        Module = vertShaderModule,
                        Name = new IntPtr (entryPointNamePointer)
                    };

                    PipelineShaderStageCreateInfo fragShaderStageInfo = new PipelineShaderStageCreateInfo
                    {
                        StructureType = StructureType.PipelineShaderStageCreateInfo,
                        Stage = ShaderStageFlags.Fragment,
                        Module = fragShaderModule,
                        Name = new IntPtr (entryPointNamePointer)
                    };

                    PipelineShaderStageCreateInfo [] shaderStages = new PipelineShaderStageCreateInfo []
                    {
                        vertShaderStageInfo,
                        fragShaderStageInfo
                    };

                    PipelineVertexInputStateCreateInfo vertexInputInfo = new PipelineVertexInputStateCreateInfo
                    {
                        StructureType = StructureType.PipelineVertexInputStateCreateInfo,
                        VertexBindingDescriptionCount = 0,
                        VertexAttributeDescriptions = IntPtr.Zero,
                        VertexAttributeDescriptionCount = 0,
                        VertexBindingDescriptions = IntPtr.Zero
                    };

                    PipelineInputAssemblyStateCreateInfo inputAssembly = new PipelineInputAssemblyStateCreateInfo
                    {
                        StructureType = StructureType.PipelineInputAssemblyStateCreateInfo,
                        Topology = PrimitiveTopology.TriangleList,
                        PrimitiveRestartEnable = false
                    };

                    Viewport viewport = new Viewport
                    {
                        X = 0.0f,
                        Y = 0.0f,
                        Width = (float) swapChainExtent.Width,
                        Height = (float) swapChainExtent.Height,
                        MinDepth = 0.0f,
                        MaxDepth = 1.0f
                    };

                    Rect2D scissor = new Rect2D
                    {
                        Offset = new Offset2D (0, 0),
                        Extent = swapChainExtent  
                    };

                    PipelineViewportStateCreateInfo viewportState = new PipelineViewportStateCreateInfo
                    {
                        StructureType = StructureType.PipelineViewportStateCreateInfo,
                        ViewportCount = 1,
                        Viewports = new IntPtr (&viewport),
                        ScissorCount = 1,
                        Scissors = new IntPtr (&scissor)
                    };

                    PipelineRasterizationStateCreateInfo rasterizer = new PipelineRasterizationStateCreateInfo
                    {
                        StructureType = StructureType.PipelineRasterizationStateCreateInfo,
                        DepthClampEnable = false,
                        RasterizerDiscardEnable = false,
                        PolygonMode = PolygonMode.Fill,
                        LineWidth = 1.0f,
                        CullMode = CullModeFlags.Back,
                        FrontFace = FrontFace.Clockwise,
                        DepthBiasEnable = false,
                        DepthBiasConstantFactor = 0.0f,
                        DepthBiasClamp = 0.0f,
                        DepthBiasSlopeFactor = 0.0f,
                    };

                    PipelineMultisampleStateCreateInfo multisampling = new PipelineMultisampleStateCreateInfo
                    {
                        StructureType = StructureType.PipelineMultisampleStateCreateInfo,
                        SampleShadingEnable = false,
                        RasterizationSamples = SampleCountFlags.Sample1,
                        MinSampleShading = 1.0f,
                        SampleMask = IntPtr.Zero,
                        AlphaToCoverageEnable = false,
                        AlphaToOneEnable = false
                    };

                    PipelineColorBlendAttachmentState colorBlendAttachment = new PipelineColorBlendAttachmentState
                    {
                        ColorWriteMask = ColorComponentFlags.R | ColorComponentFlags.G | ColorComponentFlags.B | ColorComponentFlags.A,
                        BlendEnable = false,
                        SourceColorBlendFactor = BlendFactor.One,
                        DestinationColorBlendFactor = BlendFactor.Zero,
                        ColorBlendOperation = BlendOperation.Add,
                        SourceAlphaBlendFactor = BlendFactor.One,
                        DestinationAlphaBlendFactor = BlendFactor.Zero,
                        AlphaBlendOperation = BlendOperation.Add
                    };

                    PipelineColorBlendStateCreateInfo colorBlending = new PipelineColorBlendStateCreateInfo
                    {
                        StructureType = StructureType.PipelineColorBlendStateCreateInfo,
                        LogicOperationEnable = false,
                        LogicOperation = LogicOperation.Copy,
                        AttachmentCount = 1,
                        Attachments = new IntPtr (&colorBlendAttachment)
                    };

                    PipelineLayoutCreateInfo pipelineLayoutInfo = new PipelineLayoutCreateInfo
                    {
                        StructureType = StructureType.PipelineLayoutCreateInfo,
                    };

                    pipelineLayout = device.CreatePipelineLayout (ref pipelineLayoutInfo);

                    fixed (PipelineShaderStageCreateInfo* shaderStagesPointer = &shaderStages [0])
                    {
                        GraphicsPipelineCreateInfo pipelineInfo = new GraphicsPipelineCreateInfo
                        {
                            StructureType = StructureType.GraphicsPipelineCreateInfo,
                            StageCount = 2,
                            Stages = new IntPtr (shaderStagesPointer),
                            VertexInputState = new IntPtr (&vertexInputInfo),
                            InputAssemblyState = new IntPtr (&inputAssembly),
                            RasterizationState = new IntPtr (&rasterizer),
                            MultisampleState = new IntPtr (&multisampling),
                            ColorBlendState = new IntPtr (&colorBlending),
                            Layout = pipelineLayout,
                            RenderPass = renderPass,
                            Subpass = 0,
                            DepthStencilState = IntPtr.Zero,
                            DynamicState = IntPtr.Zero,
                            BasePipelineHandle = Pipeline.Null,
                            BasePipelineIndex = -1,
                            ViewportState = new IntPtr (&viewportState)
                        };

                        graphicsPipeline = device.CreateGraphicsPipelines (PipelineCache.Null, 1, &pipelineInfo);
                    }
                }
            }
            finally
            {
                device.DestroyShaderModule (vertShaderModule);
                device.DestroyShaderModule (fragShaderModule);
            }
        }

        private unsafe ShaderModule CreateShaderModule (byte [] code)
        {
            fixed (byte* codePointer = &code [0])
            {
                ShaderModuleCreateInfo createInfo = new ShaderModuleCreateInfo
                {
                    StructureType = StructureType.ShaderModuleCreateInfo,
                    CodeSize = code.Length,
                    Code = new IntPtr(codePointer)
                };

                return device.CreateShaderModule (ref createInfo);
            }
        }

        private unsafe void CreateImageViews ()
        {
            for (int i = 0; i < swapChainImages.Count; i++)
            {
                ImageViewCreateInfo createInfo = new ImageViewCreateInfo
                {
                    StructureType = StructureType.ImageViewCreateInfo,
                    Image = swapChainImages [i],
                    ViewType = ImageViewType.Image2D,
                    Format = swapChainImageFormat,
                };

                createInfo.Components.R = ComponentSwizzle.Identity;
                createInfo.Components.G = ComponentSwizzle.Identity;
                createInfo.Components.B = ComponentSwizzle.Identity;
                createInfo.Components.A = ComponentSwizzle.Identity;

                createInfo.SubresourceRange.AspectMask = ImageAspectFlags.Color;
                createInfo.SubresourceRange.BaseMipLevel = 0;
                createInfo.SubresourceRange.LevelCount = 1;
                createInfo.SubresourceRange.BaseArrayLayer = 0;
                createInfo.SubresourceRange.LayerCount = 1;

                swapChainImageViews.Add (device.CreateImageView (ref createInfo));
            }
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

            if (physicalDevice == PhysicalDevice.Null)
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
                for (int i = 0; i < availableLayerNames.Count; i++)
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
                    createInfo.EnabledLayerCount = (uint) availableLayerNames.Count;
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

            device.DestroyCommandPool (commandPool);

            foreach (var f in swapChainFramebuffers)
                device.DestroyFramebuffer (f);

            device.DestroyPipeline (graphicsPipeline);
            device.DestroyPipelineLayout (pipelineLayout);
            device.DestroyRenderPass (renderPass);

            foreach (ImageView imageView in swapChainImageViews)
                device.DestroyImageView (imageView);

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
