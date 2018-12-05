module monomyst.vulkan.queues;

import std.typecons;

struct QueueFamilyIndices
{
    Nullable!uint graphicsFamily;

    bool isComplete ()
    {
        return !graphicsFamily.isNull;
    }
}