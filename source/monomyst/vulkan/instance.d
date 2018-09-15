module monomyst.vulkan.instance;

import erupted;
import erupted.vulkan_lib_loader;

import monomyst.vulkan.helpers;

public class Instance
{
    private VkInstance instance;

    this ()
    {
        import std.stdio : writeln;

        assert (loadGlobalLevelFunctions (), "Couldn't load global level functions for Vulkan.");

        const (VkApplicationInfo) appInfo =
        {
            apiVersion: VK_MAKE_VERSION (1, 1, 8),
            applicationVersion: VK_MAKE_VERSION (0, 1, 0),
            engineVersion: VK_MAKE_VERSION (0, 1, 0),
            pApplicationName: "MonoMyst",
            pEngineName: "MonoMyst",
        };

        const (VkInstanceCreateInfo) instanceCreateInfo =
        {
            pApplicationInfo: &appInfo
        };

        vkAssert (vkCreateInstance (&instanceCreateInfo, null, &instance), "Failed to create a Vulkan instance.");
    }
}