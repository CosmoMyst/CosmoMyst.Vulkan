module monomyst.vulkan;

import erupted;
import std.conv;
import std.stdio;
import std.string;
import std.traits;
import std.exception;
import std.algorithm;
import std.container;
import std.container.rbtree;
import derelict.glfw3;
import std.file : getcwd;
import core.stdc.string : strcmp;
import erupted.vulkan_lib_loader;

mixin DerelictGLFW3_VulkanBind;

debug
    private const bool enableValidationLayers = true;
else
    private const bool enableValidationLayers;

private const string [1] validationLayers = ["VK_LAYER_LUNARG_standard_validation"];

private const string [1] deviceExtensions = [VK_KHR_SWAPCHAIN_EXTENSION_NAME];

private const uint width = 800;
private const uint height = 600;

private GLFWwindow* window;
private VkInstance instance;
private VkPhysicalDevice physicalDevice = VK_NULL_HANDLE;
private VkDevice device;
private VkQueue graphicsQueue;
private VkQueue presentQueue;
private VkSurfaceKHR surface;
private VkSwapchainKHR swapChain;
private VkImage [] swapChainImages;
private VkFormat swapChainImageFormat;
private VkExtent2D swapChainExtent;

private VkDebugReportCallbackEXT debugCallback;

void run () // stfu
{
    initWindow ();
    initVulkan ();
    mainLoop ();
    cleanup ();
}

extern (System) static VkBool32 vulkanDebugCallback (VkDebugReportFlagsEXT flags, VkDebugReportObjectTypeEXT objType, ulong obj, //stfu
		                                              size_t location, int code, const (char*) layerPrefix, // stfu
                                                      const (char*) msg, void* userData) nothrow
{
	import std.stdio : stderr, fprintf;
	import std.string : fromStringz;

	try
    {
		stderr.writefln ("Validation layer: %s", msg.fromStringz);
	}
	catch (Exception)
    {
	}

	return VK_FALSE;
}

private void initWindow ()
{
	DerelictGLFW3.load ();

    DerelictGLFW3_loadVulkan ();

    glfwInit ();

    glfwWindowHint (GLFW_CLIENT_API, GLFW_NO_API);
    glfwWindowHint (GLFW_RESIZABLE, GLFW_FALSE);

    window = glfwCreateWindow (width, height, "MonoMyst.Vulkan", null, null);
}

private void enforceVk (VkResult result)
{
    enforce (result == VkResult.VK_SUCCESS, result.to!string);
}

private void initVulkan ()
{
    loadGlobalLevelFunctions ();

    createInstance ();

    setupDebugCallback ();

    createSurface ();

    pickPhysicalDevice ();

    createLogicalDevice ();

    createSwapChain ();
}

private void createSwapChain ()
{
    SwapChainSupportDetails details = querySwapChainSupport (physicalDevice);

    const (VkSurfaceFormatKHR) surfaceFormat = chooseSwapSurfaceFormat (details.formats);
    const (VkPresentModeKHR) presentMode = choosePresentMode (details.presentModes);
    const (VkExtent2D) extent = chooseSwapExtent (details.capabilities);

    swapChainImageFormat = surfaceFormat.format;
    swapChainExtent = extent;

    uint imageCount = details.capabilities.minImageCount + 1;
    if (details.capabilities.maxImageCount > 0 && imageCount > details.capabilities.maxImageCount)
        imageCount = details.capabilities.maxImageCount;

    VkSwapchainCreateInfoKHR createInfo = {};
    createInfo.surface = surface;
    createInfo.minImageCount = imageCount;
    createInfo.imageFormat = surfaceFormat.format;
    createInfo.imageColorSpace = surfaceFormat.colorSpace;
    createInfo.imageExtent = extent;
    createInfo.imageArrayLayers = 1;
    createInfo.imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;

    const (QueueFamilyIndices) indices = findQueueFamilies (physicalDevice);
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

    createInfo.preTransform = details.capabilities.currentTransform;
    createInfo.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
    createInfo.presentMode = presentMode;
    createInfo.clipped = VK_TRUE;
    createInfo.oldSwapchain = 0;

    vkCreateSwapchainKHR (device, &createInfo, null, &swapChain).enforceVk;

    vkGetSwapchainImagesKHR (device, swapChain, &imageCount, null);
    swapChainImages.length = imageCount;
    vkGetSwapchainImagesKHR (device, swapChain, &imageCount, &swapChainImages[0]);
}

private void createSurface ()
{
    glfwCreateWindowSurface (instance, window, null, &surface).enforceVk;
}

private void pickPhysicalDevice ()
{
    uint deviceCount;
    vkEnumeratePhysicalDevices (instance, &deviceCount, null);

    if (deviceCount == 0)
        throw new Exception ("Physical device count is 0.");

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

    if (physicalDevice == VK_NULL_HANDLE)
        throw new Exception ("Couldn't find a suitable physical device");
}

private void createLogicalDevice ()
{
    QueueFamilyIndices indices = findQueueFamilies (physicalDevice);

    float [1] queuePriorities = [1.0f];

    VkDeviceQueueCreateInfo [] queueCreateInfos;
    RedBlackTree!(int, "a < b", false) uniqueQueueFamilies = redBlackTree (indices.graphicsFamily,
                                                                           indices.presentFamily);

    foreach (queueFamily; uniqueQueueFamilies)
    {
        VkDeviceQueueCreateInfo queueCreateInfo = {};
        queueCreateInfo.queueFamilyIndex = queueFamily;
        queueCreateInfo.queueCount = 1;
        queueCreateInfo.pQueuePriorities = &queuePriorities [0];

        queueCreateInfos ~= queueCreateInfo;
    }

    const (VkPhysicalDeviceFeatures) features = {};

    VkDeviceCreateInfo deviceInfo = {};
    deviceInfo.queueCreateInfoCount = cast (uint) queueCreateInfos.length;
    deviceInfo.pQueueCreateInfos = &queueCreateInfos [0];
    deviceInfo.pEnabledFeatures = &features;
    deviceInfo.enabledExtensionCount = cast (uint) deviceExtensions.length;

    const (char)* [] extensionNames;
    foreach (ext; deviceExtensions)
        extensionNames ~= cast (const (char)*) ext;

    deviceInfo.ppEnabledExtensionNames = &extensionNames [0];

    if (enableValidationLayers)
    {
        const (char)* [] layers;
        foreach (l; validationLayers)
            layers ~= cast (const (char)*) l;

        deviceInfo.enabledLayerCount = cast (uint) layers.length;
        deviceInfo.ppEnabledLayerNames = &layers [0];
    }
    else
    {
        deviceInfo.enabledLayerCount = 0;
    }

    vkCreateDevice (physicalDevice, &deviceInfo, null, &device).enforceVk;

    loadDeviceLevelFunctions (device);

    vkGetDeviceQueue (device, indices.graphicsFamily, 0, &graphicsQueue);
    vkGetDeviceQueue (device, indices.presentFamily, 0, &presentQueue);
}

private bool isDeviceSuitable (VkPhysicalDevice device)
{
    QueueFamilyIndices indices = findQueueFamilies (device);

    immutable bool extensionsSupported = checkDeviceExtensionSupport (device);

    bool swapChainSupport;
    if (extensionsSupported)
    {
        const SwapChainSupportDetails details = querySwapChainSupport (device);
        swapChainSupport = !details.formats.length == 0 && !details.presentModes.length == 0;
    }

    return indices.isComplete () && extensionsSupported && swapChainSupport;
}

private bool checkDeviceExtensionSupport (VkPhysicalDevice device)
{
    uint extensionCount;
    vkEnumerateDeviceExtensionProperties (device, null, &extensionCount, null);

    VkExtensionProperties [] availableExtensions;
    availableExtensions.length = extensionCount;

    vkEnumerateDeviceExtensionProperties (device, null, &extensionCount, &availableExtensions [0]);

    foreach (requiredExtension; deviceExtensions)
        if (!canFind!((VkExtensionProperties a, string b) => strcmp (a.extensionName.ptr, b.ptr) == 0)
           (availableExtensions, requiredExtension))
            return false;

    return true;
}

private QueueFamilyIndices findQueueFamilies (VkPhysicalDevice device)
{
    QueueFamilyIndices indices;

    uint queueFamilyCount;
    vkGetPhysicalDeviceQueueFamilyProperties (device, &queueFamilyCount, null);

    VkQueueFamilyProperties [] queueFamilies;
    queueFamilies.length = queueFamilyCount;
    vkGetPhysicalDeviceQueueFamilyProperties (device, &queueFamilyCount, queueFamilies.ptr);

    foreach (int i, queueFamily; queueFamilies)
    {
        VkBool32 presentSupport = false;
        vkGetPhysicalDeviceSurfaceSupportKHR (device, i, surface, &presentSupport);

        if (queueFamily.queueCount > 0 && presentSupport)
            indices.presentFamily = i;

        if (queueFamily.queueCount > 0 && queueFamily.queueFlags & VK_QUEUE_GRAPHICS_BIT)
            indices.graphicsFamily = i;

        if (indices.isComplete ())
            break;
    }

    return indices;
}

private void createInstance ()
{
    if (enableValidationLayers && !checkValidationLayerSupport)
        throw new Exception ("Validation layers are enabled but there's no support for them.");

    VkApplicationInfo appInfo = {};
    appInfo.pApplicationName = "MonoMyst.Vulkan";
    appInfo.applicationVersion = VK_MAKE_VERSION (1, 0, 0);
    appInfo.pEngineName = "MonoMyst";
    appInfo.engineVersion = VK_MAKE_VERSION (1, 0, 0);
    appInfo.apiVersion = VK_MAKE_VERSION (1, 0, 2);

    VkInstanceCreateInfo createInfo = {};
    createInfo.pApplicationInfo = &appInfo;

    const(char)* [] extensions = getRequiredExtensions ();

    createInfo.enabledExtensionCount = cast (uint) extensions.length;
    createInfo.ppEnabledExtensionNames = &extensions [0];

    if (enableValidationLayers)
    {
        const (char)* [] layers;
        foreach (l; validationLayers)
            layers ~= cast (const (char)*) l;

        createInfo.enabledLayerCount = cast (uint) layers.length;
        createInfo.ppEnabledLayerNames = &layers [0];
    }
    else
    {
        createInfo.enabledLayerCount = 0;
    }

    vkCreateInstance (&createInfo, null, &instance).enforceVk;

    loadInstanceLevelFunctions (instance);
}

private void setupDebugCallback ()
{
    if (!enableValidationLayers) return;

    VkDebugReportCallbackCreateInfoEXT createInfo = {};
    createInfo.flags = VK_DEBUG_REPORT_ERROR_BIT_EXT | VK_DEBUG_REPORT_WARNING_BIT_EXT;
    createInfo.pfnCallback = assumeNoGC (&vulkanDebugCallback);

    createDebugReportCallbackEXT (instance, &createInfo, null, &debugCallback).enforceVk;
}

private static VkResult createDebugReportCallbackEXT (VkInstance instance,
                                               const VkDebugReportCallbackCreateInfoEXT* pCreateInfo,
		                                       const VkAllocationCallbacks* pAllocator, VkDebugReportCallbackEXT* pCallback)
{
	auto func = cast (PFN_vkCreateDebugReportCallbackEXT)
                vkGetInstanceProcAddr (instance, "vkCreateDebugReportCallbackEXT");
    
	if (func)
		return func (instance, pCreateInfo, pAllocator, pCallback);
	else
		return VK_ERROR_EXTENSION_NOT_PRESENT;
}

private static void destroyDebugReportCallbackEXT (VkInstance instance, VkDebugReportCallbackEXT callback,
                                            const VkAllocationCallbacks* pAllocator)
{
	auto func = cast (PFN_vkDestroyDebugReportCallbackEXT)
                vkGetInstanceProcAddr (instance, "vkDestroyDebugReportCallbackEXT");

	if (func)
		func (instance, callback, pAllocator);
}

private bool checkValidationLayerSupport ()
{
    uint layerCount;
    vkEnumerateInstanceLayerProperties (&layerCount, null);

    if (!layerCount)
        return false;

    VkLayerProperties [] availableLayers;
    availableLayers.length = layerCount;
    vkEnumerateInstanceLayerProperties (&layerCount, availableLayers.ptr);

    foreach (validationLayer; validationLayers)
    {
        bool layerFound;

        foreach (availableLayer; availableLayers)
        {
            string avla = cast (string) availableLayer.layerName;

            if (strcmp (validationLayer.ptr, avla.ptr) == 0)
            {
                layerFound = true;
                break;
            }
        }

        if (!layerFound)
            return false;
    }

    return true;
}

private const (char)* [] getRequiredExtensions ()
{
    const (char)* [] extensions;

    uint glfwExtensionCount;
    const char** glfwExtensions = glfwGetRequiredInstanceExtensions (&glfwExtensionCount);

    extensions.length = glfwExtensionCount;

    for (int i; i < glfwExtensionCount; i++)
    {
        const (string) ext = glfwExtensions [i].to!string;
        extensions [i] = cast (const (char)*) ext;
    }

    if (enableValidationLayers)
        extensions ~= VK_EXT_DEBUG_REPORT_EXTENSION_NAME;

    return extensions;
}

private void mainLoop ()
{
    while (!glfwWindowShouldClose (window))
        glfwPollEvents ();
}

private void cleanup ()
{
    vkDestroySwapchainKHR (device, swapChain, null);

    vkDestroyDevice (device, null);

    if (enableValidationLayers)
        destroyDebugReportCallbackEXT (instance, debugCallback, null);

    vkDestroySurfaceKHR (instance, surface, null);
    vkDestroyInstance (instance, null);

    glfwDestroyWindow (window);
    glfwTerminate ();
}

private auto assumeNoGC (T) (T t) nothrow if (isFunctionPointer!T || isDelegate!T)
{
	enum attrs = functionAttributes!T | FunctionAttribute.nogc;
	return cast (SetFunctionAttributes! (T, functionLinkage!T, attrs)) t;
}

private SwapChainSupportDetails querySwapChainSupport (VkPhysicalDevice device)
{
    SwapChainSupportDetails details;

    vkGetPhysicalDeviceSurfaceCapabilitiesKHR (device, surface, &details.capabilities);

    uint formatCount;
    vkGetPhysicalDeviceSurfaceFormatsKHR (device, surface, &formatCount, null);

    if (formatCount != 0)
    {
        details.formats.length = formatCount;
        vkGetPhysicalDeviceSurfaceFormatsKHR (device, surface, &formatCount, &details.formats [0]);
    }

    uint presentModeCount;
    vkGetPhysicalDeviceSurfacePresentModesKHR (device, surface, &presentModeCount, null);

    if (presentModeCount != 0)
    {
        details.presentModes.length = presentModeCount;
        vkGetPhysicalDeviceSurfacePresentModesKHR (device, surface, &presentModeCount, &details.presentModes [0]);
    }

    return details;
}

private VkSurfaceFormatKHR chooseSwapSurfaceFormat (VkSurfaceFormatKHR [] availableFormats)
{
    if (availableFormats.length == 1 && availableFormats [0].format == VK_FORMAT_UNDEFINED)
    {
        VkSurfaceFormatKHR format =
        {
            format: VK_FORMAT_B8G8R8_UNORM,
            colorSpace: VK_COLOR_SPACE_SRGB_NONLINEAR_KHR
        };

        return format;
    }

    foreach (availableFormat; availableFormats)
    {
        if (availableFormat.format == VK_FORMAT_B8G8R8_UNORM &&
        availableFormat.colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR)
            return availableFormat;
    }

    return availableFormats [0];
}

private VkPresentModeKHR choosePresentMode (VkPresentModeKHR [] availablePresentModes)
{
    VkPresentModeKHR bestMode = VK_PRESENT_MODE_FIFO_KHR;

    foreach (availablePresentMode; availablePresentModes)
    {
        if (availablePresentMode == VK_PRESENT_MODE_MAILBOX_KHR)
            return availablePresentMode;
        else if (availablePresentMode == VK_PRESENT_MODE_IMMEDIATE_KHR)
            bestMode = availablePresentMode;
    }

    return bestMode;
}

private VkExtent2D chooseSwapExtent (VkSurfaceCapabilitiesKHR capabilities)
{
    if (capabilities.currentExtent.width != uint.max)
        return capabilities.currentExtent;
    else
    {
        VkExtent2D actualExtent = {};
        actualExtent.width = width;
        actualExtent.height = height;

        actualExtent.width = max (capabilities.minImageExtent.width,
                                  min (capabilities.maxImageExtent.width, actualExtent.width));
        actualExtent.height = max (capabilities.minImageExtent.height,
                                   min (capabilities.maxImageExtent.height, actualExtent.height));

        return actualExtent;
    }
}

struct QueueFamilyIndices // stfu
{
    int graphicsFamily = -1; // stfu
    int presentFamily = -1; // stfu

    bool isComplete () // stfu
    {
        return graphicsFamily >= 0 && presentFamily >= 0;
    }
}

struct SwapChainSupportDetails // stfu
{
    VkSurfaceCapabilitiesKHR capabilities; // stfu
    VkSurfaceFormatKHR [] formats; // stfu
    VkPresentModeKHR [] presentModes; // stfu
}