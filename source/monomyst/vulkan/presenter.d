module monomyst.vulkan.presenter;

import erupted;
import erupted.platform_extensions;
import xcb.xcb;
import monomyst.core;
import monomyst.vulkan.helpers;

mixin Platform_Extensions!USE_PLATFORM_XCB_KHR;

class Presenter
{
    @property VkSurfaceKHR vkSurface () { return surface; }
    private VkSurfaceKHR surface;
    private VkInstance instance;

    this (VkInstance instance, Window window)
    {
        this.instance = instance;

        VkXcbSurfaceCreateInfoKHR createInfo =
        {
            connection: window.xcbconnection,
            window: window.xcbwindow
        };

        auto createXcbSurfaceKHR = cast (PFN_vkCreateXcbSurfaceKHR) vkGetInstanceProcAddr (instance, "vkCreateXcbSurfaceKHR");

        assert (createXcbSurfaceKHR !is null, "Function is null");
        vkAssert (createXcbSurfaceKHR (instance, &createInfo, null, &surface), "Failed to create XCB Surface");
    }

    void cleanup ()
    {
        vkDestroySurfaceKHR (instance, surface, null);
    }
}