module monomyst.vulkan.queues;

import std.typecons;

struct QueueFamilyIndices
{
    Nullable!ulong graphicsFamily;

    bool isComplete ()
    {
        return !graphicsFamily.isNull;
    }
}