module monomyst.vulkan.instance;

import erupted;
import erupted.vulkan_lib_loader;

public class Instance
{
    this ()
    {
        loadGlobalLevelFunctions ();

        VkInstanceCreateInfo instanceCreateInfo = {};

        // vkCreateInstance ();
    }
}