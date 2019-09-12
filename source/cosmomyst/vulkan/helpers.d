module cosmomyst.vulkan.helpers;

import erupted;
import std.traits;

public void vkAssert (VkResult vkResult, string message)
{
    import std.format : format;

    assert (vkResult == VkResult.VK_SUCCESS, format ("%s: %s", vkResult, message));
}

public auto assumeNoGC (T) (T t) nothrow if (isFunctionPointer!T || isDelegate!T)
{
	enum attrs = functionAttributes!T | FunctionAttribute.nogc;
	return cast (SetFunctionAttributes! (T, functionLinkage!T, attrs)) t;
}

public const (char)* [] toVulkanArray (const string [] array)
{
    const (char)* [] res;
    foreach (e; array)
        res ~= cast (const (char)*) e;

    return res;
}

public const (char)* [] toVulkanArray (const string element)
{
    return toVulkanArray ([ element ]);
}
