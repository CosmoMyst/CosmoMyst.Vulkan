module cosmomyst.vulkan.presenter;

import erupted;
import cosmomyst.vulkan.device;
import cosmomyst.vulkan.swapchain;

class Presenter
{
    private VkImage [] images;
    public VkImageView [] imageViews;

    private Device device;

    this (Device device)
    {
        this.device = device;

        images = getSwapchainImages (device.device, device.swapchain.swapchain);

        createImageViews ();
    }

    private void createImageViews ()
    {
        import cosmomyst.vulkan.helpers : vkAssert;

        foreach (VkImage image; images)
        {
            VkComponentMapping components =
            {
                r: VK_COMPONENT_SWIZZLE_IDENTITY,
                g: VK_COMPONENT_SWIZZLE_IDENTITY,
                b: VK_COMPONENT_SWIZZLE_IDENTITY,
                a: VK_COMPONENT_SWIZZLE_IDENTITY
            };

            VkImageSubresourceRange subresourceRange =
            {
                aspectMask: VK_IMAGE_ASPECT_COLOR_BIT,
                baseMipLevel: 0,
                levelCount: 1,
                baseArrayLayer: 0,
                layerCount: 1
            };

            VkImageViewCreateInfo createInfo =
            {
                sType: VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
                image: image,
                viewType: VK_IMAGE_VIEW_TYPE_2D,
                format: device.swapchain.format,
                components: components,
                subresourceRange: subresourceRange
            };

            VkImageView imageView;

            vkAssert (vkCreateImageView (device.device, &createInfo, null, &imageView), "Failed to create an image view.");

            imageViews ~= imageView;
        }
    }

    void cleanup ()
    {
        foreach (VkImageView imageView; imageViews)
        {
            vkDestroyImageView (device.device, imageView, null);
        }
    }
}
