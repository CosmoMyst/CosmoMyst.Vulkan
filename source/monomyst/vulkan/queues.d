module monomyst.vulkan.queues;

import std.typecons;

struct QueueFamilyIndices
{
    Nullable!uint graphicsFamily;
    Nullable!uint presentFamily;

    bool isComplete ()
    {
        return !graphicsFamily.isNull && !presentFamily.isNull;
    }
}