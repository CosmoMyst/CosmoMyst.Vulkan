using System;
using System.Runtime.InteropServices;

using SharpVulkan;

using Vk = SharpVulkan;

namespace MonoMyst.Vulkan
{
    public unsafe class Device : IDisposable
    {
        private PhysicalDevice physicalDevice;
        private Vk.Device logicalDevice;

        private Instance instance;

        private readonly bool enableDebug;

        public Device (Instance instance, bool enableDebug)
        {
            this.instance = instance;
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

            float* queuePriorities = stackalloc float [1];
            queuePriorities [0] = 1.0f;

            DeviceQueueCreateInfo queueCreateInfo = new DeviceQueueCreateInfo
            {
                StructureType = StructureType.DeviceQueueCreateInfo,
                QueueFamilyIndex = (uint) indices.GraphicsFamily,
                QueueCount = 1,
                QueuePriorities = (IntPtr) queuePriorities,
            };

            PhysicalDeviceFeatures deviceFeatures = new PhysicalDeviceFeatures ();

            DeviceCreateInfo createInfo = new DeviceCreateInfo
            {
                StructureType = StructureType.DeviceCreateInfo,
                QueueCreateInfoCount = 1,
                QueueCreateInfos = new IntPtr (&queueCreateInfo),
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

                if (indices.IsComplete ())
                    break;
            }

            return indices;
        }

        public void Dispose ()
        {
            logicalDevice.Destroy ();
        }
    }
}
