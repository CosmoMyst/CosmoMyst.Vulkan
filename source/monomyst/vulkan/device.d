module monomyst.vulkan.device;

import erupted;
import std.typecons;
import monomyst.vulkan.queues;
import monomyst.vulkan.instance;

public class Device
{
    private VkPhysicalDevice physicalDevice;
    private VkDevice device;
    private VkInstance instance;

    this (VkInstance instance)
    {
        this.instance = instance;

        pickPhysicalDevice ();
    }

    private void pickPhysicalDevice ()
    {
        uint deviceCount;
        vkEnumeratePhysicalDevices (instance, &deviceCount, null);

        assert (deviceCount != 0, "Failed to find GPUs with Vulkan support.");

        VkPhysicalDevice [] devices;
        devices.length = deviceCount;

        vkEnumeratePhysicalDevices (instance, &deviceCount, devices.ptr);

        foreach (device; devices)
        {
            if (isDeviceSuitable (device))
            {
                physicalDevice = device;
                break;
            }
        }

        assert (physicalDevice !is null, "Failed to find a suitable GPU.");
    }

    private bool isDeviceSuitable (VkPhysicalDevice device)
    {
        QueueFamilyIndices indices = findQueueFamilies (device);

        return indices.isComplete;
    }

    private QueueFamilyIndices findQueueFamilies (VkPhysicalDevice device)
    {
        QueueFamilyIndices indices;

        uint queueFamilyCount;
        vkGetPhysicalDeviceQueueFamilyProperties (device, &queueFamilyCount, null);

        VkQueueFamilyProperties [] queueFamilies;
        queueFamilies.length = queueFamilyCount;
        vkGetPhysicalDeviceQueueFamilyProperties (device, &queueFamilyCount, queueFamilies.ptr);

        foreach (i, queueFamily; queueFamilies)
        {
            if (queueFamily.queueCount > 0 && queueFamily.queueFlags & VK_QUEUE_GRAPHICS_BIT)
                indices.graphicsFamily = i;

            if (indices.isComplete)
                break;
        }

        return indices;
    }
}