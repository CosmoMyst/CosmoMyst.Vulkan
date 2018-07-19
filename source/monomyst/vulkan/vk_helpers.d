module monomyst.vulkan.vk_helpers;

import erupted;

package void vkAssert (VkResult result, string message)
{
    import std.stdio : stderr;
    import std.exception : enforce;

    if (result != VkResult.VK_SUCCESS)
        stderr.writeln (result, ": ", message);
}