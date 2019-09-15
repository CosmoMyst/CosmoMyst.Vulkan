module cosmomyst.vulkan.renderpass;

import erupted;
import cosmomyst.vulkan.swapchain;
import cosmomyst.vulkan.device;

public class RenderPass
{
    public VkRenderPass renderPass;

    private Device device;

    this (Device device)
    {
        import cosmomyst.vulkan.helpers : vkAssert;

        this.device = device;

        VkAttachmentDescription colourAttachment =
        {
            format: device.swapchain.format,
            samples: VK_SAMPLE_COUNT_1_BIT,
            loadOp: VK_ATTACHMENT_LOAD_OP_CLEAR,
            storeOp: VK_ATTACHMENT_STORE_OP_STORE,
            stencilLoadOp: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
            stencilStoreOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
            initialLayout: VK_IMAGE_LAYOUT_UNDEFINED,
            finalLayout: VK_IMAGE_LAYOUT_PRESENT_SRC_KHR
        };

        VkAttachmentReference colourAttachmentRef =
        {
            attachment: 0,
            layout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
        };

        VkSubpassDescription subpass =
        {
            pipelineBindPoint: VK_PIPELINE_BIND_POINT_GRAPHICS,
            colorAttachmentCount: 1,
            pColorAttachments: &colourAttachmentRef
        };

        VkRenderPassCreateInfo createInfo =
        {
            attachmentCount: 1,
            pAttachments: &colourAttachment,
            subpassCount: 1,
            pSubpasses: &subpass
        };

        vkAssert (vkCreateRenderPass (device.device, &createInfo, null, &renderPass), "Failed to create a render pass");
    }

    public void cleanup ()
    {
        vkDestroyRenderPass (device.device, renderPass, null);
    }
}
