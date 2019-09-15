module cosmomyst.vulkan.surface;

import erupted;
import erupted.platform_extensions;
import xcb.xcb;
import cosmomyst.core.window;
import cosmomyst.vulkan.helpers;

mixin Platform_Extensions!USE_PLATFORM_XCB_KHR;

public VkSurfaceKHR createSurface (VkInstance instance, XCBWindow window)
{
    VkSurfaceKHR surface;

    VkXcbSurfaceCreateInfoKHR createInfo =
    {
        connection: window.connection,
        window: window.window
    };

    auto createXcbSurfaceKHR = cast (PFN_vkCreateXcbSurfaceKHR) vkGetInstanceProcAddr (instance, "vkCreateXcbSurfaceKHR");

    assert (createXcbSurfaceKHR !is null, "Function is null");
    vkAssert (createXcbSurfaceKHR (instance, &createInfo, null, &surface), "Failed to create XCB Surface");

    return surface;
}
