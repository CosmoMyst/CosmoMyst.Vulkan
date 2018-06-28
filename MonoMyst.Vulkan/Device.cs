using System;

using SharpVulkan;

using Vk = SharpVulkan;

namespace MonoMyst.Vulkan
{
    public unsafe class Device : IDisposable
    {
        private PhysicalDevice physicalDevice;

        private Instance instance;

        public Device (Instance instance)
        {
            this.instance = instance;

            PickPhysicalDevice ();
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
        }
    }
}
