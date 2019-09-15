module cosmomyst.vulkan.commands;

import erupted;
import cosmomyst.vulkan.queues;
import cosmomyst.vulkan.device;
import cosmomyst.vulkan.framebuffer;

public class CommandPool
{
    private VkCommandPool commandPool;

    private VkCommandBuffer [] commandBuffers;

    private Device device;
    private Framebuffer framebuffer;

    public void delegate (VkCommandBuffer cmdBuffer, VkFramebuffer framebuffer) renderPassDelegate;

    this (Device device, Framebuffer framebuffer)
    {
        import cosmomyst.vulkan.helpers : vkAssert;

        this.device = device;
        this.framebuffer = framebuffer;

        QueueFamilyIndices indices = findQueueFamilies (device.physicalDevice, device.surface);

        VkCommandPoolCreateInfo createInfo =
        {
            queueFamilyIndex: indices.graphicsFamily.get (),
        };

        vkAssert (vkCreateCommandPool (device.device, &createInfo, null, &commandPool), "Failed to create a command pool");

        commandBuffers.length = framebuffer.framebuffers.length;

        VkCommandBufferAllocateInfo allocInfo =
        {
            commandPool: commandPool,
            level: VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            commandBufferCount: cast (uint) commandBuffers.length
        };

        vkAssert (vkAllocateCommandBuffers (device.device, &allocInfo, &commandBuffers [0]), "Failed to allocate command buffers");
    }

    public void record ()
    {
        import cosmomyst.vulkan.helpers : vkAssert;
        
        foreach (i, VkCommandBuffer cmd; commandBuffers)
        {
            VkCommandBufferBeginInfo beginInfo = {};

            vkAssert (vkBeginCommandBuffer (cmd, &beginInfo), "Failed to begin recording a command buffer");

            renderPassDelegate (cmd, framebuffer.framebuffers [i]);

            vkAssert (vkEndCommandBuffer (cmd), "Failed to record a command buffer");
        }
    }

    public void cleanup ()
    {
        vkDestroyCommandPool (device.device, commandPool, null);
    }
}
