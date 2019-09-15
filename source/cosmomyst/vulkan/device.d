module cosmomyst.vulkan.device;

import erupted;
import erupted.vulkan_lib_loader;
import std.typecons;
import cosmomyst.vulkan.queues;
import cosmomyst.vulkan.instance;
import cosmomyst.vulkan.swapchain;

private const string [] requiredDeviceExtensions =
[
    VK_KHR_SWAPCHAIN_EXTENSION_NAME
];

public class Device
{
    public VkPhysicalDevice physicalDevice;
    public VkDevice device;
    public VkSurfaceKHR surface;
    private VkInstance instance;
    private VkQueue graphicsQueue;
    private VkQueue presentQueue;

    public Swapchain swapchain;

    this (VkInstance instance, VkSurfaceKHR surface, uint width, uint height)
    {
        this.instance = instance;
        this.surface = surface;

        pickPhysicalDevice ();
        createLogicalDevice ();

        swapchain = createSwapchain (physicalDevice, device, surface, width, height);
    }

    private void createLogicalDevice ()
    {
        import cosmomyst.vulkan.layers : getValidationLayers;
        import cosmomyst.vulkan.helpers : vkAssert, toVulkanArray;
        import std.container : RedBlackTree, redBlackTree;

        QueueFamilyIndices indices = findQueueFamilies (physicalDevice, surface);
        
        VkDeviceQueueCreateInfo [] queueCreateInfos;

        RedBlackTree!(uint, "a < b", false) uniqueQueueFamilies = redBlackTree (indices.graphicsFamily.get,
                                                                               indices.presentFamily.get);

        float queuePriority = 1;

        foreach (queueFamily; uniqueQueueFamilies)
        {
            VkDeviceQueueCreateInfo queueCreateInfo =
            {
                queueFamilyIndex: queueFamily,
                queueCount: 1,
                pQueuePriorities: &queuePriority
            };
            queueCreateInfos ~= queueCreateInfo;
        }

        VkPhysicalDeviceFeatures deviceFeatures;

        VkDeviceCreateInfo createInfo =
        {
            queueCreateInfoCount: cast (uint) queueCreateInfos.length,
            pQueueCreateInfos: &queueCreateInfos [0],
            pEnabledFeatures: &deviceFeatures,
            enabledExtensionCount: cast (uint) requiredDeviceExtensions.length,
            ppEnabledExtensionNames: &requiredDeviceExtensions.toVulkanArray () [0]
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

        vkGetDeviceQueue (device, indices.graphicsFamily.get, 0, &graphicsQueue);
        vkGetDeviceQueue (device, indices.presentFamily.get, 0, &presentQueue);
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
        import cosmomyst.vulkan.swapchain : SwapchainSupport, querySwapchainSupport;

        QueueFamilyIndices indices = findQueueFamilies (device, surface);

        bool extensionsSupported = checkExtensionSupport (device);

        bool swapchainSupported;

        if (extensionsSupported)
        {
            SwapchainSupport swapchainSupport = querySwapchainSupport (device, surface);
            swapchainSupported = swapchainSupport.formats.length > 0 && swapchainSupport.presentModes.length > 0;
        }

        return indices.isComplete && extensionsSupported && swapchainSupported;
    }

    private bool checkExtensionSupport (VkPhysicalDevice device)
    {
        import std.algorithm : canFind;
        import core.stdc.string : strcmp;

        uint extensionCount;
        vkEnumerateDeviceExtensionProperties (device, null, &extensionCount, null);

        VkExtensionProperties [] availableExtensions;
        availableExtensions.length = extensionCount;

        vkEnumerateDeviceExtensionProperties (device, null, &extensionCount, availableExtensions.ptr);

        foreach (requiredExtension; requiredDeviceExtensions)
        {
            if (!canFind! ((a, b) => strcmp (a.extensionName.ptr, b.ptr) == 0) (availableExtensions, requiredExtension))
            {
                return false;
            }
        }

        return true;
    }

    void cleanup ()
    {
        vkDestroySwapchainKHR (device, swapchain.swapchain, null);
        vkDestroyDevice (device, null);
    }
}

public QueueFamilyIndices findQueueFamilies (VkPhysicalDevice device, VkSurfaceKHR surface)
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

        VkBool32 presentSupport;
        vkGetPhysicalDeviceSurfaceSupportKHR (device, i, surface, &presentSupport);

        if (queueFamily.queueCount > 0 && presentSupport)
            indices.presentFamily = i;

        if (indices.isComplete)
            break;
    }

    return indices;
}
