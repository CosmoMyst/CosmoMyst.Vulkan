module monomyst.vulkan.device;

import erupted;
import erupted.vulkan_lib_loader;
import std.typecons;
import monomyst.vulkan.queues;
import monomyst.vulkan.instance;

public class Device
{
    private VkPhysicalDevice physicalDevice;
    private VkDevice device;
    private VkInstance instance;
    private VkQueue graphicsQueue;

    this (VkInstance instance)
    {
        this.instance = instance;

        pickPhysicalDevice ();
        createLogicalDevice ();
    }

    private void createLogicalDevice ()
    {
        import monomyst.vulkan.layers : getValidationLayers;
        import monomyst.vulkan.helpers : vkAssert;

        QueueFamilyIndices indices = findQueueFamilies (physicalDevice);

        float queuePriority = 1;

        VkDeviceQueueCreateInfo queueCreateInfo =
        {
            queueFamilyIndex: indices.graphicsFamily.get,
            queueCount: 1,
            pQueuePriorities: &queuePriority
        };

        VkPhysicalDeviceFeatures deviceFeatures;

        VkDeviceCreateInfo createInfo =
        {
            pQueueCreateInfos: &queueCreateInfo,
            queueCreateInfoCount: 1,
            pEnabledFeatures: &deviceFeatures,
            enabledExtensionCount: 0
        };

        debug
        {
            auto validationLayers = getValidationLayers ();

            createInfo.enabledLayerCount = cast (uint) validationLayers.length;
            createInfo.ppEnabledLayerNames = &validationLayers [0];
        }
        else
        {
            createInfo.enabledLayerCount = 0;
        }

        vkAssert (vkCreateDevice (physicalDevice, &createInfo, null, &device), "Failed to create a logical device.");

        loadDeviceLevelFunctions (device);

        vkGetDeviceQueue (device, indices.graphicsFamily, 0, &graphicsQueue);
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

        foreach (uint i, queueFamily; queueFamilies)
        {
            if (queueFamily.queueCount > 0 && queueFamily.queueFlags & VK_QUEUE_GRAPHICS_BIT)
                indices.graphicsFamily = i;

            if (indices.isComplete)
                break;
        }

        return indices;
    }

    void cleanup ()
    {
        vkDestroyDevice (device, null);
    }
}