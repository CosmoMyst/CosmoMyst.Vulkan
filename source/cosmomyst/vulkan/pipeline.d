module cosmomyst.vulkan.pipeline;

import erupted;
import cosmomyst.vulkan.device;
import cosmomyst.vulkan.renderpass;

public class GraphicsPipeline
{
    private Device device;

    private VkPipelineLayout pipelineLayout;
    private RenderPass renderPass;

    private VkPipeline pipeline;

    this (Device device)
    {
        import std.file : read, thisExePath;
        import std.path : chainPath, dirName;
        import cosmomyst.vulkan.helpers : vkAssert;

        this.device = device;

        ubyte [] vertShaderCode = cast (ubyte []) read (chainPath (dirName (thisExePath), "vert.spv"));
        ubyte [] fragShaderCode = cast (ubyte []) read (chainPath (dirName (thisExePath), "frag.spv"));

        VkShaderModule vertShaderModule = createShaderModule (vertShaderCode);
        VkShaderModule fragShaderModule = createShaderModule (fragShaderCode);

        VkPipelineShaderStageCreateInfo vertShaderStageInfo =
        {
            stage: VK_SHADER_STAGE_VERTEX_BIT,
            _module: vertShaderModule,
            pName: "main"
        };

        VkPipelineShaderStageCreateInfo fragShaderStageInfo =
        {
            stage: VK_SHADER_STAGE_FRAGMENT_BIT,
            _module: fragShaderModule,
            pName: "main"
        };

        VkPipelineShaderStageCreateInfo [] shaderStages = [vertShaderStageInfo, fragShaderStageInfo];

        VkPipelineVertexInputStateCreateInfo vertexInputInfo =
        {
            vertexBindingDescriptionCount: 0,
            vertexAttributeDescriptionCount: 0
        };

        VkPipelineInputAssemblyStateCreateInfo inputAssembly =
        {
            topology: VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
            primitiveRestartEnable: VK_FALSE
        };

        VkViewport viewport =
        {
            x: 0.0,
            y: 0.0,
            width: device.swapchain.extent.width,
            height: device.swapchain.extent.height,
            minDepth: 0.0,
            maxDepth: 1.0
        };

        VkRect2D scissor =
        {
            offset: VkOffset2D (0, 0),
            extent: device.swapchain.extent
        };

        VkPipelineViewportStateCreateInfo viewportState =
        {
            viewportCount: 1,
            pViewports: &viewport,
            scissorCount: 1,
            pScissors: &scissor
        };

        VkPipelineRasterizationStateCreateInfo rasterizer =
        {
            depthClampEnable: VK_FALSE,
            rasterizerDiscardEnable: VK_FALSE,
            polygonMode: VK_POLYGON_MODE_FILL,
            lineWidth: 1.0,
            cullMode: VK_CULL_MODE_BACK_BIT,
            frontFace: VK_FRONT_FACE_CLOCKWISE,
            depthBiasEnable: VK_FALSE,
            depthBiasClamp: 0
        };

        VkPipelineMultisampleStateCreateInfo multisampling =
        {
            sampleShadingEnable: VK_FALSE,
            rasterizationSamples: VK_SAMPLE_COUNT_1_BIT
        };

        VkPipelineColorBlendAttachmentState colourBlendAttachment =
        {
            colorWriteMask: VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT | VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT,
            blendEnable: VK_FALSE
        };

        VkPipelineColorBlendStateCreateInfo colourBlending =
        {
            logicOpEnable: VK_FALSE,
            attachmentCount: 1,
            pAttachments: &colourBlendAttachment
        };

        VkPipelineLayoutCreateInfo pipelineLayoutInfo = {};

        vkAssert (vkCreatePipelineLayout (device.device, &pipelineLayoutInfo, null, &pipelineLayout), "Failed to create a pipeline layout");

        renderPass = new RenderPass (device);

        VkGraphicsPipelineCreateInfo createInfo =
        {
            stageCount: 2,
            pStages: &shaderStages [0],
            pVertexInputState: &vertexInputInfo,
            pInputAssemblyState: &inputAssembly,
            pViewportState: &viewportState,
            pRasterizationState: &rasterizer,
            pMultisampleState: &multisampling,
            pColorBlendState: &colourBlending,
            layout: pipelineLayout,
            renderPass: renderPass.renderPass,
            subpass: 0
        };

        vkAssert (vkCreateGraphicsPipelines (device.device, VK_NULL_HANDLE, 1, &createInfo, null, &pipeline), "Failed to create a graphics pipeline.");

        vkDestroyShaderModule (device.device, vertShaderModule, null);
        vkDestroyShaderModule (device.device, fragShaderModule, null);
    }

    private VkShaderModule createShaderModule (ubyte [] code)
    {
        import cosmomyst.vulkan.helpers : vkAssert;
        
        VkShaderModuleCreateInfo createInfo =
        {
            codeSize: cast (uint) code.length,
            pCode: cast (uint*) code.ptr
        };

        VkShaderModule shaderModule;
        vkAssert (vkCreateShaderModule (device.device, &createInfo, null, &shaderModule), "Failed to create a shader module.");

        return shaderModule;
    }

    public void cleanup ()
    {
        vkDestroyPipeline (device.device, pipeline, null);
        vkDestroyPipelineLayout (device.device, pipelineLayout, null);
        renderPass.cleanup ();
    }
}
