using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

using SharpVulkan;

using static MonoMyst.Glfw.Glfw;

using Vk = SharpVulkan;

namespace MonoMyst.Vulkan
{
    public unsafe class Device : IDisposable
    {
        private PhysicalDevice physicalDevice;
        public Vk.Device logicalDevice;

        private Queue graphicsQueue;
        private Queue presentQueue;

        private Instance instance;
        private Surface surface;

        private readonly bool enableDebug;

        public Device (Instance instance, Surface surface, bool enableDebug)
        {
            this.instance = instance;
            this.surface = surface;
            this.enableDebug = enableDebug;

            PickPhysicalDevice ();
            CreateLogicalDevice ();
        }

        private void PickPhysicalDevice ()
        {
            PhysicalDevice [] physicalDevices = instance.PhysicalDevices;

            if (physicalDevices.Length == 0)
                throw new Exception ("Failed to find GPUs with vulkan support.");

            foreach (PhysicalDevice physicalDevice in physicalDevices)
                if (IsPhysicalDeviceSuitable (physicalDevice))
                {
                    this.physicalDevice = physicalDevice;
                    break;
                }

            if (physicalDevice == PhysicalDevice.Null)
                throw new Exception ("Failed to find a suitable GPU.");
        }

        private bool IsPhysicalDeviceSuitable (PhysicalDevice device)
        {
            QueueFamilyIndices indices = FindQueueFamilies (device);

            return indices.IsComplete ();
        }

        private void CreateLogicalDevice ()
        {
            QueueFamilyIndices indices = FindQueueFamilies (physicalDevice);

            SortedSet<int> uniqueQueueFamilies = new SortedSet<int> ()
            {
                indices.GraphicsFamily,
                indices.PresentFamily
            };

            DeviceQueueCreateInfo* queueCreateInfos = stackalloc DeviceQueueCreateInfo [uniqueQueueFamilies.Count];

            float queuePriorities = 1.0f;

            {
                int i = 0;
                foreach (int queueFamily in uniqueQueueFamilies)
                {
                    queueCreateInfos [i] = new DeviceQueueCreateInfo
                    {
                        StructureType = StructureType.DeviceQueueCreateInfo,
                        QueueFamilyIndex = (uint) queueFamily,
                        QueueCount = 1,
                        QueuePriorities = new IntPtr (&queuePriorities)
                    };

                    i++;
                }
            }

            PhysicalDeviceFeatures deviceFeatures = new PhysicalDeviceFeatures ();

            DeviceCreateInfo createInfo = new DeviceCreateInfo
            {
                StructureType = StructureType.DeviceCreateInfo,
                QueueCreateInfoCount = (uint) uniqueQueueFamilies.Count,
                QueueCreateInfos = (IntPtr) queueCreateInfos,
                EnabledFeatures = new IntPtr (&deviceFeatures),
                EnabledExtensionCount = 0
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

            logicalDevice = physicalDevice.CreateDevice (ref createInfo);

            graphicsQueue = logicalDevice.GetQueue ((uint) indices.GraphicsFamily, 0);
            presentQueue = logicalDevice.GetQueue ((uint) indices.PresentFamily, 0);

            if (enableDebug)
                foreach (IntPtr i in validationLayersPtr)
                    Marshal.FreeHGlobal (i);
        }

        private QueueFamilyIndices FindQueueFamilies (PhysicalDevice device)
        {
            QueueFamilyIndices indices = new QueueFamilyIndices ();

            QueueFamilyProperties [] properties = device.QueueFamilyProperties;

            for (int i = 0; i < properties.Length; i++)
            {
                if (properties [i].QueueCount > 0 && (properties [i].QueueFlags & QueueFlags.Graphics) != 0)
                    indices.GraphicsFamily = i;

                bool presentSupport = device.GetSurfaceSupport ((uint) i, surface);

                if (properties [i].QueueCount > 0 && presentSupport)
                    indices.PresentFamily = i;

                if (indices.IsComplete ())
                    break;
            }

            return indices;
        }

        public void Dispose () => logicalDevice.Destroy ();
    }
}
