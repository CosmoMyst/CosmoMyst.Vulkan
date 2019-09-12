module cosmomyst.vulkan.layers;

import erupted;

/++
    Vulkan standard validation layer name.
+/
enum VK_STANDARD_VALIDATION_LAYER_NAME = "VK_LAYER_LUNARG_standard_validation"; 

/++
    Checks if validation layers are supported.
+/
bool checkValidationLayerSupport ()
{
    import core.stdc.string : strcmp;

    uint propertyCount;
    vkEnumerateInstanceLayerProperties (&propertyCount, null);

    if (propertyCount == 0) return false;

    VkLayerProperties [] layerProperties;
    layerProperties.length = propertyCount;

    vkEnumerateInstanceLayerProperties (&propertyCount, layerProperties.ptr);

    foreach (VkLayerProperties layer; layerProperties)
    {
        if (strcmp (layer.layerName.ptr, VK_STANDARD_VALIDATION_LAYER_NAME.ptr) == 0)
            return true;
    }

    return false;
}

const (char)* [] getValidationLayers ()
{
    import cosmomyst.vulkan.helpers : toVulkanArray;

    return VK_STANDARD_VALIDATION_LAYER_NAME.toVulkanArray;
}
