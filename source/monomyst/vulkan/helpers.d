module monomyst.vulkan.helpers;

import erupted;

public void vkAssert (VkResult vkResult, string message)
{
    import std.format : format;

    assert (vkResult == VkResult.VK_SUCCESS, format ("%s: %s", vkResult, message));
}