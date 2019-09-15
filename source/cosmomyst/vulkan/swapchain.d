module cosmomyst.vulkan.swapchain;

import erupted;

public struct SwapchainSupport
{
    public VkSurfaceCapabilitiesKHR capabilities;
    public VkSurfaceFormatKHR [] formats;
    public VkPresentModeKHR [] presentModes;
}

public struct Swapchain
{
    public VkSwapchainKHR swapchain;
    public VkFormat format;
    public VkExtent2D extent;
}

public SwapchainSupport querySwapchainSupport (VkPhysicalDevice device, VkSurfaceKHR surface)
{
    SwapchainSupport support;

    vkGetPhysicalDeviceSurfaceCapabilitiesKHR (device, surface, &support.capabilities);

    uint formatCount;
    vkGetPhysicalDeviceSurfaceFormatsKHR (device, surface, &formatCount, null);

    if (formatCount != 0)
    {
        support.formats.length = formatCount;
        vkGetPhysicalDeviceSurfaceFormatsKHR (device, surface, &formatCount, support.formats.ptr);
    }

    uint presentModesCount;
    vkGetPhysicalDeviceSurfacePresentModesKHR (device, surface, &presentModesCount, null);

    if (presentModesCount != 0)
    {
        support.presentModes.length = presentModesCount;
        vkGetPhysicalDeviceSurfacePresentModesKHR (device, surface, &presentModesCount, support.presentModes.ptr);
    }

    return support;
}

public Swapchain createSwapchain (VkPhysicalDevice physicalDevice, VkDevice device, VkSurfaceKHR surface, uint width, uint height)
{
    import cosmomyst.vulkan.queues : QueueFamilyIndices;
    import cosmomyst.vulkan.device : findQueueFamilies;
    import cosmomyst.vulkan.helpers : vkAssert;

    VkSwapchainKHR res;

    SwapchainSupport support = querySwapchainSupport (physicalDevice, surface);

    VkSurfaceFormatKHR format = chooseSwapSurfaceFormat (support.formats);
    VkPresentModeKHR presentMode = chooseSwapPresentMode (support.presentModes);
    VkExtent2D extent = chooseSwapExtent (support.capabilities, width, height);

    uint imageCount = support.capabilities.minImageCount + 1;

    if (support.capabilities.maxImageCount > 0 && imageCount > support.capabilities.maxImageCount)
    {
        imageCount = support.capabilities.maxImageCount;
    }

    VkSwapchainCreateInfoKHR createInfo =
    {
        sType: VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
        surface: surface,
        minImageCount: imageCount,
        imageFormat: format.format,
        imageColorSpace: format.colorSpace,
        imageExtent: extent,
        imageArrayLayers: 1,
        imageUsage: VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
        preTransform: support.capabilities.currentTransform,
        compositeAlpha: VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
        presentMode: presentMode,
        clipped: VK_TRUE,
        oldSwapchain: VK_NULL_HANDLE
    };

    QueueFamilyIndices indices = findQueueFamilies (physicalDevice, surface);
    uint [] queueFamilyIndices = [cast (uint) indices.graphicsFamily, cast (uint) indices.presentFamily];

    if (indices.graphicsFamily != indices.presentFamily)
    {
        createInfo.imageSharingMode = VK_SHARING_MODE_CONCURRENT;
        createInfo.queueFamilyIndexCount = 2;
        createInfo.pQueueFamilyIndices = &queueFamilyIndices [0];
    }
    else
    {
        createInfo.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;
    }

    vkAssert (vkCreateSwapchainKHR (device, &createInfo, null, &res), "Failed to create a swapchain.");

    return Swapchain (res, format.format, extent);
}

public VkImage [] getSwapchainImages (VkDevice device, VkSwapchainKHR swapchain)
{
    VkImage [] images;
    uint imageCount;

    vkGetSwapchainImagesKHR (device, swapchain, &imageCount, null);
    images.length = imageCount;
    vkGetSwapchainImagesKHR (device, swapchain, &imageCount, images.ptr);

    return images;
}

private VkSurfaceFormatKHR chooseSwapSurfaceFormat (const VkSurfaceFormatKHR [] availableFormats)
{
    foreach (VkSurfaceFormatKHR format; availableFormats)
    {
        if (format.format == VK_FORMAT_B8G8R8A8_UNORM && format.colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR)
        {
            return format;
        }
    }

    return availableFormats [0];
}

private VkPresentModeKHR chooseSwapPresentMode (const VkPresentModeKHR [] availableModes)
{
    foreach (VkPresentModeKHR mode; availableModes)
    {
        if (mode == VK_PRESENT_MODE_MAILBOX_KHR)
        {
            return mode;
        }
    }

    return VK_PRESENT_MODE_FIFO_KHR;
}

private VkExtent2D chooseSwapExtent (const VkSurfaceCapabilitiesKHR capabilities, uint width, uint height)
{
    import std.algorithm.comparison : clamp;

    if (capabilities.currentExtent.width != uint.max)
    {
        return capabilities.currentExtent;
    }
    else
    {
        VkExtent2D extent = VkExtent2D (width, height);

        extent.width = clamp (extent.width, capabilities.minImageExtent.width, capabilities.maxImageExtent.width);
        extent.height = clamp (extent.height, capabilities.minImageExtent.height, capabilities.maxImageExtent.height);

        return extent;
    }
}
