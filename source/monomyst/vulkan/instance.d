module monomyst.vulkan.instance;

import erupted;
import erupted.vulkan_lib_loader;

import monomyst.vulkan.layers;
import monomyst.vulkan.helpers;

public class Instance
{
    @property public VkInstance vkInstance () { return instance; }
    private VkInstance instance;
    private VkDebugReportCallbackEXT debugCallback;

    this ()
    {
        import std.stdio : writeln;
        import std.string : toStringz;

        assert (loadGlobalLevelFunctions (), "Couldn't load global level functions for Vulkan.");

        debug
            assert (checkValidationLayerSupport (), "There is no support for validation layers.");

        const VkApplicationInfo appInfo =
        {
            apiVersion: VK_MAKE_VERSION (1, 1, 8),
            applicationVersion: VK_MAKE_VERSION (0, 1, 0),
            engineVersion: VK_MAKE_VERSION (0, 1, 0),
            pApplicationName: "MonoMyst",
            pEngineName: "MonoMyst",
        };

        auto extensions = getRequiredExtensions ().toVulkanArray;

        VkInstanceCreateInfo instanceCreateInfo =
        {
            pApplicationInfo: &appInfo,
            enabledExtensionCount: cast (uint) extensions.length,
            ppEnabledExtensionNames: &extensions [0]
        };

        debug
        {
            auto validationLayers = getValidationLayers ();

            instanceCreateInfo.enabledLayerCount = cast (uint) validationLayers.length;
            instanceCreateInfo.ppEnabledLayerNames = &validationLayers [0];
        }
        else
        {
            instanceCreateInfo.enabledLayerCount = 0;
        }

        vkAssert (vkCreateInstance (&instanceCreateInfo, null, &instance), "Failed to create a Vulkan instance.");

        loadInstanceLevelFunctions (instance);

        setupDebugCallback ();
    }

    private string [] getRequiredExtensions ()
    {
        string [] extensions;

        debug
            extensions ~= VK_EXT_DEBUG_REPORT_EXTENSION_NAME;

        return extensions;
    }

    private void setupDebugCallback ()
    {
        debug
        {
            VkDebugReportCallbackCreateInfoEXT createInfo =
            {
                flags: VK_DEBUG_REPORT_ERROR_BIT_EXT | VK_DEBUG_REPORT_WARNING_BIT_EXT,
                pfnCallback: assumeNoGC (&vulkanDebugCallback)
            };

            vkAssert (createDebugReportCallbackEXT (instance, &createInfo, null, &debugCallback),
                      "Failed to create a debug report callback");
        }
    }

    ~this ()
    {
        debug
            destroyDebugReportCallbackEXT (instance, debugCallback, null);

        vkDestroyInstance (instance, null);
    }
}

private static VkResult createDebugReportCallbackEXT (VkInstance instance,
                                                      const VkDebugReportCallbackCreateInfoEXT* pCreateInfo,
                                                      const VkAllocationCallbacks* pAllocator,
                                                      VkDebugReportCallbackEXT* pCallback)
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

extern (System)
private static VkBool32 vulkanDebugCallback (VkDebugReportFlagsEXT flags, VkDebugReportObjectTypeEXT objType, ulong obj,
                                             size_t location, int code, const (char*) layerPrefix,
                                             const (char*) msg, void* userData) nothrow
{
	import std.stdio : stderr, fprintf;
	import std.string : fromStringz;

	try
    {
		stderr.writefln ("Validation layer: %s", msg.fromStringz);
	}
	catch (Exception) { }

	return VK_FALSE;
}
