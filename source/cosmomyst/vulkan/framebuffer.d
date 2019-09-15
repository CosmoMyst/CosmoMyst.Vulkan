module cosmomyst.vulkan.framebuffer;

import erupted;
import cosmomyst.vulkan.presenter;
import cosmomyst.vulkan.pipeline;
import cosmomyst.vulkan.device;

public class Framebuffer
{
    public VkFramebuffer [] framebuffers;

    private Device device;

    this (Presenter presenter, GraphicsPipeline pipeline, Device device)
    {
        import cosmomyst.vulkan.helpers : vkAssert;

        this.device = device;

        foreach (VkImageView imageView; presenter.imageViews)
        {
            VkFramebufferCreateInfo createInfo =
            {
                renderPass: pipeline.renderPass.renderPass,
                attachmentCount: 1,
                pAttachments: &imageView,
                width: device.swapchain.extent.width,
                height: device.swapchain.extent.height,
                layers: 1
            };

            VkFramebuffer fb;

            vkAssert (vkCreateFramebuffer (device.device, &createInfo, null, &fb), "Failed to create a framebuffer");

            framebuffers ~= fb;
        }
    }

    public void cleanup ()
    {
        foreach (VkFramebuffer fb; framebuffers)
        {
            vkDestroyFramebuffer (device.device, fb, null);
        }
    }
}
