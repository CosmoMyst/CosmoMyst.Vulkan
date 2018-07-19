module monomyst.vulkan.main;

import erupted;
import std.conv;
import std.file;
import std.stdio;
import std.string;
import std.traits;
import std.exception;
import std.algorithm;
import std.container;
import derelict.glfw3;
import std.file : getcwd;
import core.stdc.string : strcmp;
import erupted.vulkan_lib_loader;
import monomyst.math;
import std.datetime.stopwatch;
import monomyst.vulkan.window;
import monomyst.vulkan.vk_helpers;

private const string [1] validationLayers = ["VK_LAYER_LUNARG_standard_validation"];

private const string [1] deviceExtensions = [VK_KHR_SWAPCHAIN_EXTENSION_NAME];

private const uint width = 800;
private const uint height = 600;

private const int maxFramesInFlight = 2;

private VkSemaphore [] imageAvailableSemaphores;
private VkSemaphore [] renderFinishedSemaphores;
private VkFence [] inFlightFences;

private VkInstance instance;
private VkPhysicalDevice physicalDevice = VK_NULL_HANDLE;
private VkDevice device;
private VkQueue graphicsQueue;
private VkQueue presentQueue;
private VkSurfaceKHR surface;
private VkSwapchainKHR swapChain;
private VkImage [] swapChainImages;
private VkImageView [] swapChainImageViews;
private VkFormat swapChainImageFormat;
private VkExtent2D swapChainExtent;
private VkRenderPass renderPass;
private VkPipelineLayout pipelineLayout;
private VkPipeline graphicsPipeline;
private VkFramebuffer [] swapChainFramebuffers;
private VkCommandPool commandPool;
private VkCommandBuffer [] commandBuffers;
private VkBuffer vertexBuffer;
private VkDeviceMemory vertexBufferMemory;
private VkBuffer indexBuffer;
private VkDeviceMemory indexBufferMemory;
private VkDescriptorSetLayout descriptorSetLayout;
private VkBuffer [] uniformBuffers;
private VkDeviceMemory [] uniformBuffersMemory;

private size_t currentFrame;

private VkDebugReportCallbackEXT debugCallback;

private Vertex [4] vertices;

private ushort [6] indices = [0, 1, 2, 2, 3, 0];

private Window window;

void run () // stfu
{
    startTime = MonoTime.currTime;

    // NOTE: This should be in the module (outside of a function) but then all components are nan.
    // No clue why this is.
    vertices =
    [
        Vertex (Vector2 (-0.5f, -0.5f), Vector3 (1.0f, 0.0f, 0.0f)),
        Vertex (Vector2 (0.5f, -0.5f),  Vector3 (0.0f, 1.0f, 0.0f)),
        Vertex (Vector2 (0.5f, 0.5f),   Vector3 (0.0f, 0.0f, 1.0f)),
        Vertex (Vector2 (-0.5f, 0.5f),  Vector3 (0.4f, 0.1f, 0.9f))
    ];


    window = new Window ("MonoMyst.Vulkan", width, height);
    window.setWindowUserPointer (&window);
    window.setFramebufferSizeCallback (&framebufferSizeCallback);
    
    initVulkan ();
    mainLoop ();
    cleanup ();
}

extern (C)
private void framebufferSizeCallback (GLFWwindow* glfwWindow, int width, int height) nothrow
{
    const void* data = glfwGetWindowUserPointer (glfwWindow);
    Window w = cast (Window) data;
    w.frameBufferResized = true;
}

extern (System)
private static VkBool32 vulkanDebugCallback (VkDebugReportFlagsEXT flags, VkDebugReportObjectTypeEXT objType, ulong obj, //stfu
                                             size_t location, int code, const (char*) layerPrefix, // stfu
                                             const (char*) msg, void* userData) nothrow
{
	import std.stdio : stderr, fprintf;
	import std.string : fromStringz;

	try
    {
		stderr.writefln ("Validation layer: %s", msg.fromStringz);
	}
	catch (Exception)
    {
	}

	return VK_FALSE;
}

private void initVulkan ()
{
    loadGlobalLevelFunctions ();

    createInstance ();

    setupDebugCallback ();

    createSurface ();

    pickPhysicalDevice ();

    createLogicalDevice ();

    createSwapChain ();

    createImageViews ();

    createRenderPass ();

    createDescriptorSetLayout ();

    createGraphicsPipeline ();

    createFramebuffers ();

    createCommandPool ();

    createVertexBuffer ();

    createIndexBuffer ();

    createUniformBuffer ();

    createCommandBuffers ();

    createSyncObjects ();
}

private StopWatch sw = StopWatch (AutoStart.no);
private MonoTime startTime;

private void updateUniformBuffer ()
{
    auto currentTime = MonoTime.currTime;

    auto time = currentTime - startTime;
    float timeF = time.total!"seconds";
}

private void createUniformBuffer ()
{
    VkDeviceSize bufferSize = UniformBufferObject.sizeof;

    uniformBuffers.length = swapChainImages.length;
    uniformBuffersMemory.length = swapChainImages.length;

    for (int i; i < swapChainImages.length; i++)
    {
        createBuffer (bufferSize, VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, uniformBuffers [i], uniformBuffersMemory [i]);
    }
}

private void createDescriptorSetLayout ()
{
    VkDescriptorSetLayoutBinding uboLayoutBinding = {};
    uboLayoutBinding.binding = 0;
    uboLayoutBinding.descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
    uboLayoutBinding.descriptorCount = 1;
    uboLayoutBinding.stageFlags = VK_SHADER_STAGE_VERTEX_BIT;

    VkDescriptorSetLayoutCreateInfo layoutInfo = {};
    layoutInfo.bindingCount = 1;
    layoutInfo.pBindings = &uboLayoutBinding;

    vkAssert (vkCreateDescriptorSetLayout (device, &layoutInfo, null, &descriptorSetLayout),
              "Failed to create a descriptor layout");
}

private void createIndexBuffer ()
{
    import core.stdc.string : memcpy;

    VkDeviceSize bufferSize = indices [0].sizeof * indices.length;

    VkBuffer stagingBuffer;
    VkDeviceMemory stagingBufferMemory;

    createBuffer (bufferSize, VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
                              VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT |
                              VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
                              stagingBuffer, stagingBufferMemory);

    void* data;
    vkMapMemory (device, stagingBufferMemory, 0, bufferSize, 0, &data);
    memcpy (data, &indices [0], cast (size_t) bufferSize);
    vkUnmapMemory (device, stagingBufferMemory);

    createBuffer (bufferSize, VK_BUFFER_USAGE_TRANSFER_DST_BIT |
                              VK_BUFFER_USAGE_INDEX_BUFFER_BIT,
                              VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
                              indexBuffer, indexBufferMemory);

    copyBuffer (stagingBuffer, indexBuffer, bufferSize);

    vkDestroyBuffer (device, stagingBuffer, null);
    vkFreeMemory (device, stagingBufferMemory, null);
}

private void createBuffer (VkDeviceSize size, VkBufferUsageFlags usage, VkMemoryPropertyFlags properties,
                           ref VkBuffer buffer, ref VkDeviceMemory bufferMemory)
{
    VkBufferCreateInfo bufferInfo = {};
    bufferInfo.size = size;
    bufferInfo.usage = usage;
    bufferInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;

    vkAssert (vkCreateBuffer (device, &bufferInfo, null, &buffer),
              "Failed to create a buffer");

    VkMemoryRequirements memRequirements;
    vkGetBufferMemoryRequirements (device, buffer, &memRequirements);

    VkMemoryAllocateInfo allocInfo = {};
    allocInfo.allocationSize = memRequirements.size;
    allocInfo.memoryTypeIndex = findMemoryType (memRequirements.memoryTypeBits, properties);

    vkAssert (vkAllocateMemory (device, &allocInfo, null, &bufferMemory),
              "Failed to allocate buffer memory");

    vkBindBufferMemory (device, buffer, bufferMemory, 0);
}

private void copyBuffer (VkBuffer srcBuffer, VkBuffer dstBuffer, VkDeviceSize size)
{
    VkCommandBufferAllocateInfo allocInfo = {};
    allocInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    allocInfo.commandPool = commandPool;
    allocInfo.commandBufferCount = 1;

    VkCommandBuffer cmdBuffer;

    vkAllocateCommandBuffers (device, &allocInfo, &cmdBuffer);

    VkCommandBufferBeginInfo beginInfo = {};
    beginInfo.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;

    vkBeginCommandBuffer (cmdBuffer, &beginInfo);

        VkBufferCopy copyRegion = {};
        copyRegion.size = size;

        vkCmdCopyBuffer (cmdBuffer, srcBuffer, dstBuffer, 1, &copyRegion);

    vkEndCommandBuffer (cmdBuffer);

    VkSubmitInfo submitInfo = {};
    submitInfo.commandBufferCount = 1;
    submitInfo.pCommandBuffers = &cmdBuffer;

    vkQueueSubmit (graphicsQueue, 1, &submitInfo, VK_NULL_HANDLE);
    vkQueueWaitIdle (graphicsQueue);

    vkFreeCommandBuffers (device, commandPool, 1, &cmdBuffer);
}

private void createVertexBuffer ()
{
    import core.stdc.string : memcpy;

    VkDeviceSize bufferSize = vertices [0].sizeof * vertices.length;

    VkBuffer stagingBuffer;
    VkDeviceMemory stagingBufferMemory;

    createBuffer (bufferSize, VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
                              VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT |
                              VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
                              stagingBuffer, stagingBufferMemory);

    void* data;
    vkMapMemory (device, stagingBufferMemory, 0, bufferSize, 0, &data);
    memcpy (data, &vertices [0], cast (size_t) bufferSize);
    vkUnmapMemory (device, stagingBufferMemory);

    createBuffer (bufferSize, VK_BUFFER_USAGE_TRANSFER_DST_BIT |
                              VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
                              VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
                              vertexBuffer, vertexBufferMemory);

    copyBuffer (stagingBuffer, vertexBuffer, bufferSize);

    vkDestroyBuffer (device, stagingBuffer, null);
    vkFreeMemory (device, stagingBufferMemory, null);
}

private uint findMemoryType (uint typeFilter, VkMemoryPropertyFlags properties)
{
    VkPhysicalDeviceMemoryProperties memProperties;
    vkGetPhysicalDeviceMemoryProperties (physicalDevice, &memProperties);

    for (int i; i < memProperties.memoryTypeCount; i++)
        if ((typeFilter & (1 << i)) && (memProperties.memoryTypes [i].propertyFlags & properties) == properties)
            return i;

    throw new Exception ("Failed to find suitable memory type.");
}

private void recreateSwapCain ()
{
    int ewidth = 0;
    int eheight = 0;
    while (ewidth == 0 || eheight == 0)
    {
        window.getFramebufferSize (&ewidth, &eheight);
        window.waitEvents ();
    }

    vkDeviceWaitIdle (device);

    cleanupSwapChain ();

    createSwapChain ();
    createImageViews ();
    createRenderPass ();
    createGraphicsPipeline ();
    createFramebuffers ();
    createCommandBuffers ();
}

private void createSyncObjects ()
{
    imageAvailableSemaphores.length = maxFramesInFlight;
    renderFinishedSemaphores.length = maxFramesInFlight;
    inFlightFences.length = maxFramesInFlight;

    VkSemaphoreCreateInfo semaphoreInfo = {};

    VkFenceCreateInfo fenceInfo = {};
    fenceInfo.flags = VK_FENCE_CREATE_SIGNALED_BIT;

    for (int i; i < maxFramesInFlight; i++)
    {
        vkAssert (vkCreateSemaphore (device, &semaphoreInfo, null, &imageAvailableSemaphores [i]),
                  "Failed to create a semaphore");
        vkAssert (vkCreateSemaphore (device, &semaphoreInfo, null, &renderFinishedSemaphores [i]),
                  "Failed to create a semaphore");
        vkAssert (vkCreateFence (device, &fenceInfo, null, &inFlightFences [i]),
                  "Failed to create a fence");
    }
}

private void createCommandBuffers ()
{
    commandBuffers.length = swapChainFramebuffers.length;

    VkCommandBufferAllocateInfo allocInfo = {};
    allocInfo.commandPool = commandPool;
    allocInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    allocInfo.commandBufferCount = cast (uint) commandBuffers.length;

    vkAssert (vkAllocateCommandBuffers (device, &allocInfo, &commandBuffers [0]),
              "Failed to allocate command buffers");

    foreach (size_t i, cmdBuffer; commandBuffers)
    {
        VkCommandBufferBeginInfo beginInfo = {};
        beginInfo.flags = VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT;

        vkAssert (vkBeginCommandBuffer (cmdBuffer, &beginInfo),
                  "Failed to begin a command buffer");

        VkRenderPassBeginInfo renderPassInfo = {};
        renderPassInfo.renderPass = renderPass;
        renderPassInfo.framebuffer = swapChainFramebuffers [i];
        renderPassInfo.renderArea.offset.x = 0;
        renderPassInfo.renderArea.offset.y = 0;
        renderPassInfo.renderArea.extent = swapChainExtent;

        VkClearValue clearColor = {};
        clearColor.color.float32 = [0.0f, 0.0f, 0.0f, 1.0f];

        renderPassInfo.clearValueCount = 1;
        renderPassInfo.pClearValues = &clearColor;

        vkCmdBeginRenderPass (cmdBuffer, &renderPassInfo, VK_SUBPASS_CONTENTS_INLINE);

            vkCmdBindPipeline (cmdBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, graphicsPipeline);

            VkBuffer [1] vertexBuffers = [vertexBuffer];
            VkDeviceSize [1] offsets = [0];
            vkCmdBindVertexBuffers (cmdBuffer, 0, 1, &vertexBuffers [0], &offsets [0]);

            vkCmdBindIndexBuffer (cmdBuffer, indexBuffer, 0, VK_INDEX_TYPE_UINT16);

            Vector3 tintColor = Vector3 (0.53f, 0.4f, 0.15f);

            vkCmdPushConstants (cmdBuffer, pipelineLayout, VK_SHADER_STAGE_VERTEX_BIT, 0, Vector3.sizeof, &tintColor);

            vkCmdDrawIndexed (cmdBuffer, cast (uint) indices.length, 1, 0, 0, 0);

        vkCmdEndRenderPass (cmdBuffer);

        vkAssert (vkEndCommandBuffer (cmdBuffer),
                  "Failed to end a command buffer");
    }
}

private void createCommandPool ()
{
    QueueFamilyIndices indices = findQueueFamilies (physicalDevice);

    VkCommandPoolCreateInfo poolInfo = {};
    poolInfo.queueFamilyIndex = indices.graphicsFamily;

    vkAssert (vkCreateCommandPool (device, &poolInfo, null, &commandPool),
              "Failed to create a command pool");
}

private void createFramebuffers ()
{
    swapChainFramebuffers.length = swapChainImageViews.length;

    foreach (int i, imageView; swapChainImageViews)
    {
        VkImageView [1] attachments = [imageView];

        VkFramebufferCreateInfo framebufferInfo = {};
        framebufferInfo.renderPass = renderPass;
        framebufferInfo.attachmentCount = 1;
        framebufferInfo.pAttachments = &attachments [0];
        framebufferInfo.width = swapChainExtent.width;
        framebufferInfo.height = swapChainExtent.height;
        framebufferInfo.layers = 1;

        vkAssert (vkCreateFramebuffer (device, &framebufferInfo, null, &swapChainFramebuffers [i]),
                  "Failed to create a framebuffer");
    }
}

private void createRenderPass ()
{
    VkAttachmentDescription colorAttachment = {};
    colorAttachment.format = swapChainImageFormat;
    colorAttachment.samples = VK_SAMPLE_COUNT_1_BIT;
    colorAttachment.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR;
    colorAttachment.storeOp = VK_ATTACHMENT_STORE_OP_STORE;
    colorAttachment.stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
    colorAttachment.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
    colorAttachment.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    colorAttachment.finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

    VkAttachmentReference colorAttachmentRef = {};
    colorAttachmentRef.attachment = 0;
    colorAttachmentRef.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

    VkSubpassDescription subpass = {};
    subpass.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS;
    subpass.colorAttachmentCount = 1;
    subpass.pColorAttachments = &colorAttachmentRef;

    VkRenderPassCreateInfo renderPassInfo = {};
    renderPassInfo.attachmentCount = 1;
    renderPassInfo.pAttachments = &colorAttachment;
    renderPassInfo.subpassCount = 1;
    renderPassInfo.pSubpasses = &subpass;

    VkSubpassDependency dependency = {};
    dependency.dstSubpass = 0;
    dependency.srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    dependency.srcAccessMask = 0;
    dependency.dstStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    dependency.dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_READ_BIT |
                               VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;

    renderPassInfo.dependencyCount = 1;
    renderPassInfo.pDependencies = &dependency;

    vkAssert (vkCreateRenderPass (device, &renderPassInfo, null, &renderPass),
              "Failed to create a render pass");
}

private void createGraphicsPipeline ()
{
    import std.file : readFile = read;

    ubyte [] vertShaderCode = cast (ubyte []) readFile (format ("%s/../vert.spv", thisExePath));
    ubyte [] fragShaderCode = cast (ubyte []) readFile (format ("%s/../frag.spv", thisExePath));

    VkShaderModule vertShaderModule = createShaderModule (vertShaderCode);
    VkShaderModule fragShaderModule = createShaderModule (fragShaderCode);

    VkPipelineShaderStageCreateInfo vertShaderStageInfo = {};
    vertShaderStageInfo.stage = VK_SHADER_STAGE_VERTEX_BIT;
    vertShaderStageInfo._module = vertShaderModule;
    vertShaderStageInfo.pName = "main";

    VkPipelineShaderStageCreateInfo fragShaderStageInfo = {};
    fragShaderStageInfo.stage = VK_SHADER_STAGE_FRAGMENT_BIT;
    fragShaderStageInfo._module = fragShaderModule;
    fragShaderStageInfo.pName = "main";

    VkPipelineShaderStageCreateInfo [] shaderStages = [vertShaderStageInfo, fragShaderStageInfo];

    VkPipelineVertexInputStateCreateInfo  vertexInputInfo = {};
    vertexInputInfo.vertexBindingDescriptionCount = 0;
    vertexInputInfo.vertexAttributeDescriptionCount = 0;

    auto bindingDescription = Vertex.getBindingDescription ();
    auto attributeDescriptions = Vertex.getAttributeDescriptions ();

    vertexInputInfo.vertexBindingDescriptionCount = 1;
    vertexInputInfo.vertexAttributeDescriptionCount = cast (uint) attributeDescriptions.length;
    vertexInputInfo.pVertexBindingDescriptions = &bindingDescription;
    vertexInputInfo.pVertexAttributeDescriptions = &attributeDescriptions [0];

    VkPipelineInputAssemblyStateCreateInfo inputAssembly = {};
    inputAssembly.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
    inputAssembly.primitiveRestartEnable = VK_FALSE;

    VkViewport viewport = {};
    viewport.x = 0.0f;
    viewport.y = 0.0f;
    viewport.width = cast (float) swapChainExtent.width;
    viewport.height = cast (float) swapChainExtent.height;
    viewport.minDepth = 0.0f;
    viewport.maxDepth = 1.0f;

    VkRect2D scissor = {};
    scissor.offset.x = 0;
    scissor.offset.y = 0;
    scissor.extent = swapChainExtent;

    VkPipelineViewportStateCreateInfo viewportState = {};
    viewportState.viewportCount = 1;
    viewportState.pViewports = &viewport;
    viewportState.scissorCount = 1;
    viewportState.pScissors = &scissor;

    VkPipelineRasterizationStateCreateInfo rasterizer = {};
    rasterizer.depthClampEnable = VK_FALSE;
    rasterizer.depthBiasClamp = 0;
    rasterizer.rasterizerDiscardEnable = VK_FALSE;
    rasterizer.polygonMode = VK_POLYGON_MODE_FILL;
    rasterizer.lineWidth = 1.0f;
    rasterizer.cullMode = VK_CULL_MODE_BACK_BIT;
    rasterizer.frontFace = VK_FRONT_FACE_CLOCKWISE;
    rasterizer.depthBiasEnable = VK_FALSE;

    VkPipelineMultisampleStateCreateInfo multisampling = {};
    multisampling.sampleShadingEnable = VK_FALSE;
    multisampling.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT;

    VkPipelineColorBlendAttachmentState colorBlendAttachement = {};
    colorBlendAttachement.colorWriteMask = VK_COLOR_COMPONENT_R_BIT |
                                           VK_COLOR_COMPONENT_G_BIT |
                                           VK_COLOR_COMPONENT_B_BIT |
                                           VK_COLOR_COMPONENT_A_BIT;
    colorBlendAttachement.blendEnable = VK_FALSE;

    VkPipelineColorBlendStateCreateInfo colorBlending = {};
    colorBlending.logicOpEnable = VK_FALSE;
    colorBlending.attachmentCount = 1;
    colorBlending.pAttachments = &colorBlendAttachement;

    VkDynamicState [] dynamicStates = [VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_LINE_WIDTH];

    VkPipelineDynamicStateCreateInfo dynamicState = {};
    dynamicState.dynamicStateCount = 2;
    dynamicState.pDynamicStates = &dynamicStates [0];

    VkPipelineLayoutCreateInfo pipelineLayoutInfo = {};
    pipelineLayoutInfo.pushConstantRangeCount = 1;
    pipelineLayoutInfo.setLayoutCount = 1;
    pipelineLayoutInfo.pSetLayouts = &descriptorSetLayout;

    VkPushConstantRange [1] pushContants;
    pushContants [0].stageFlags = VK_SHADER_STAGE_VERTEX_BIT;
    pushContants [0].offset = 0;
    pushContants [0].size = Vector3.sizeof;

    pipelineLayoutInfo.pPushConstantRanges = &pushContants [0];

    vkAssert (vkCreatePipelineLayout (device, &pipelineLayoutInfo, null, &pipelineLayout),
              "Failed to create a pipeline layout");

    VkGraphicsPipelineCreateInfo pipelineInfo = {};
    pipelineInfo.stageCount = 2;
    pipelineInfo.pStages = &shaderStages[0];
    pipelineInfo.pVertexInputState = &vertexInputInfo;
    pipelineInfo.pInputAssemblyState = &inputAssembly;
    pipelineInfo.pViewportState = &viewportState;
    pipelineInfo.pRasterizationState = &rasterizer;
    pipelineInfo.pMultisampleState = &multisampling;
    pipelineInfo.pDepthStencilState = null;
    pipelineInfo.pColorBlendState = &colorBlending;
    pipelineInfo.pDynamicState = null;
    pipelineInfo.layout = pipelineLayout;
    pipelineInfo.renderPass = renderPass;
    pipelineInfo.subpass = 0;

    vkAssert (vkCreateGraphicsPipelines (device, VK_NULL_HANDLE, 1, &pipelineInfo, null, &graphicsPipeline),
              "Failed to create a graphics pipeline");

    vkDestroyShaderModule (device, fragShaderModule, null);
    vkDestroyShaderModule (device, vertShaderModule, null);
}

private VkShaderModule createShaderModule (ubyte [] code)
{
    VkShaderModuleCreateInfo createInfo = {};
    createInfo.codeSize = cast (uint) code.length;
    createInfo.pCode = cast (uint*) code.ptr;

    VkShaderModule shaderModule;
    vkAssert (vkCreateShaderModule (device, &createInfo, null, &shaderModule),
              "Failed to create a shader module");

    return shaderModule;
}

private void createImageViews ()
{
    swapChainImageViews.length = swapChainImages.length;

    foreach (int i, swapChainImage; swapChainImages)
    {
        VkImageViewCreateInfo createInfo = {};
        createInfo.image = swapChainImages [i];
        createInfo.viewType = VK_IMAGE_VIEW_TYPE_2D;
        createInfo.format = swapChainImageFormat;
        createInfo.components.r = VK_COMPONENT_SWIZZLE_IDENTITY;
        createInfo.components.g = VK_COMPONENT_SWIZZLE_IDENTITY;
        createInfo.components.b = VK_COMPONENT_SWIZZLE_IDENTITY;
        createInfo.components.a = VK_COMPONENT_SWIZZLE_IDENTITY;
        createInfo.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        createInfo.subresourceRange.baseMipLevel = 0;
        createInfo.subresourceRange.levelCount = 1;
        createInfo.subresourceRange.baseArrayLayer = 0;
        createInfo.subresourceRange.layerCount = 1;

        vkAssert (vkCreateImageView (device, &createInfo, null, &swapChainImageViews [i]),
                  "Failed to create an image view");
    }
}

private void createSwapChain ()
{
    SwapChainSupportDetails details = querySwapChainSupport (physicalDevice);

    const (VkSurfaceFormatKHR) surfaceFormat = chooseSwapSurfaceFormat (details.formats);
    const (VkPresentModeKHR) presentMode = choosePresentMode (details.presentModes);
    const (VkExtent2D) extent = chooseSwapExtent (details.capabilities);

    swapChainImageFormat = surfaceFormat.format;
    swapChainExtent = extent;

    uint imageCount = details.capabilities.minImageCount + 1;
    if (details.capabilities.maxImageCount > 0 && imageCount > details.capabilities.maxImageCount)
        imageCount = details.capabilities.maxImageCount;

    VkSwapchainCreateInfoKHR createInfo = {};
    createInfo.surface = surface;
    createInfo.minImageCount = imageCount;
    createInfo.imageFormat = surfaceFormat.format;
    createInfo.imageColorSpace = surfaceFormat.colorSpace;
    createInfo.imageExtent = extent;
    createInfo.imageArrayLayers = 1;
    createInfo.imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;

    const (QueueFamilyIndices) indices = findQueueFamilies (physicalDevice);
    uint [] queueFamilyIndices = [cast (uint) indices.graphicsFamily, cast (uint) indices.presentFamily];

    if (indices.graphicsFamily != indices.presentFamily)
    {
        createInfo.imageSharingMode = VK_SHARING_MODE_CONCURRENT;
        createInfo.queueFamilyIndexCount = 2;
        createInfo.pQueueFamilyIndices = &queueFamilyIndices [0];
    }
    else
    {
        createInfo.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;
    }

    createInfo.preTransform = details.capabilities.currentTransform;
    createInfo.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
    createInfo.presentMode = presentMode;
    createInfo.clipped = VK_TRUE;
    createInfo.oldSwapchain = VK_NULL_HANDLE;

    vkAssert (vkCreateSwapchainKHR (device, &createInfo, null, &swapChain),
              "Failed to create a swapchain");

    vkGetSwapchainImagesKHR (device, swapChain, &imageCount, null);
    swapChainImages.length = imageCount;
    vkGetSwapchainImagesKHR (device, swapChain, &imageCount, &swapChainImages[0]);
}

private void createSurface ()
{
    window.createSurface (instance, &surface);
}

private void pickPhysicalDevice ()
{
    uint deviceCount;
    vkEnumeratePhysicalDevices (instance, &deviceCount, null);

    if (deviceCount == 0)
        throw new Exception ("Physical device count is 0.");

    VkPhysicalDevice [] devices;
    devices.length = deviceCount;

    vkEnumeratePhysicalDevices (instance, &deviceCount, devices.ptr);

    foreach (device; devices)
    {
        if (isDeviceSuitable (device))
        {
            physicalDevice = device;
            break;
        }
    }

    if (physicalDevice == VK_NULL_HANDLE)
        throw new Exception ("Couldn't find a suitable physical device");
}

private void createLogicalDevice ()
{
    QueueFamilyIndices indices = findQueueFamilies (physicalDevice);

    float [1] queuePriorities = [1.0f];

    VkDeviceQueueCreateInfo [] queueCreateInfos;
    RedBlackTree!(int, "a < b", false) uniqueQueueFamilies = redBlackTree (indices.graphicsFamily,
                                                                           indices.presentFamily);

    foreach (queueFamily; uniqueQueueFamilies)
    {
        VkDeviceQueueCreateInfo queueCreateInfo = {};
        queueCreateInfo.queueFamilyIndex = queueFamily;
        queueCreateInfo.queueCount = 1;
        queueCreateInfo.pQueuePriorities = &queuePriorities [0];

        queueCreateInfos ~= queueCreateInfo;
    }

    const (VkPhysicalDeviceFeatures) features = {};

    VkDeviceCreateInfo deviceInfo = {};
    deviceInfo.queueCreateInfoCount = cast (uint) queueCreateInfos.length;
    deviceInfo.pQueueCreateInfos = &queueCreateInfos [0];
    deviceInfo.pEnabledFeatures = &features;
    deviceInfo.enabledExtensionCount = cast (uint) deviceExtensions.length;

    const (char)* [] extensionNames;
    foreach (ext; deviceExtensions)
        extensionNames ~= cast (const (char)*) ext;

    deviceInfo.ppEnabledExtensionNames = &extensionNames [0];

    debug
    {
        const (char)* [] layers;
        foreach (l; validationLayers)
            layers ~= cast (const (char)*) l;

        deviceInfo.enabledLayerCount = cast (uint) layers.length;
        deviceInfo.ppEnabledLayerNames = &layers [0];
    }
    else
    {
        deviceInfo.enabledLayerCount = 0;
    }

    vkAssert (vkCreateDevice (physicalDevice, &deviceInfo, null, &device),
              "Failed to create a device");

    loadDeviceLevelFunctions (device);

    vkGetDeviceQueue (device, indices.graphicsFamily, 0, &graphicsQueue);
    vkGetDeviceQueue (device, indices.presentFamily, 0, &presentQueue);
}

private bool isDeviceSuitable (VkPhysicalDevice device)
{
    QueueFamilyIndices indices = findQueueFamilies (device);

    immutable bool extensionsSupported = checkDeviceExtensionSupport (device);

    bool swapChainSupport;
    if (extensionsSupported)
    {
        const SwapChainSupportDetails details = querySwapChainSupport (device);
        swapChainSupport = !details.formats.length == 0 && !details.presentModes.length == 0;
    }

    return indices.isComplete () && extensionsSupported && swapChainSupport;
}

private bool checkDeviceExtensionSupport (VkPhysicalDevice device)
{
    uint extensionCount;
    vkEnumerateDeviceExtensionProperties (device, null, &extensionCount, null);

    VkExtensionProperties [] availableExtensions;

    availableExtensions.length = extensionCount;

    vkEnumerateDeviceExtensionProperties (device, null, &extensionCount, &availableExtensions [0]);

    foreach (requiredExtension; deviceExtensions)
        if (!canFind!((VkExtensionProperties a, string b) => strcmp (a.extensionName.ptr, b.ptr) == 0)
           (availableExtensions, requiredExtension))
            return false;

    return true;
}

private QueueFamilyIndices findQueueFamilies (VkPhysicalDevice device)
{
    QueueFamilyIndices indices;

    uint queueFamilyCount;
    vkGetPhysicalDeviceQueueFamilyProperties (device, &queueFamilyCount, null);

    VkQueueFamilyProperties [] queueFamilies;
    queueFamilies.length = queueFamilyCount;
    vkGetPhysicalDeviceQueueFamilyProperties (device, &queueFamilyCount, queueFamilies.ptr);

    foreach (int i, queueFamily; queueFamilies)
    {
        VkBool32 presentSupport = false;
        vkGetPhysicalDeviceSurfaceSupportKHR (device, i, surface, &presentSupport);

        if (queueFamily.queueCount > 0 && presentSupport)
            indices.presentFamily = i;

        if (queueFamily.queueCount > 0 && queueFamily.queueFlags & VK_QUEUE_GRAPHICS_BIT)
            indices.graphicsFamily = i;

        if (indices.isComplete ())
            break;
    }

    return indices;
}

private void createInstance ()
{
    debug
        assert (checkValidationLayerSupport, "Validation layers are enabled but there's no support for them.");

    VkApplicationInfo appInfo = {};
    appInfo.pApplicationName = "MonoMyst.Vulkan";
    appInfo.applicationVersion = VK_MAKE_VERSION (1, 0, 0);
    appInfo.pEngineName = "MonoMyst";
    appInfo.engineVersion = VK_MAKE_VERSION (1, 0, 0);
    appInfo.apiVersion = VK_MAKE_VERSION (1, 0, 2);

    VkInstanceCreateInfo createInfo = {};
    createInfo.pApplicationInfo = &appInfo;

    string [] extensions = window.getRequiredExtensions ();

    const (char)* [] extPtrs;
    foreach (e; extensions)
        extPtrs ~= cast (const (char)*) e;

    createInfo.enabledExtensionCount = cast (uint) extensions.length;
    createInfo.ppEnabledExtensionNames = &extPtrs [0];

    debug
    {
        const (char)* [] layers;
        foreach (l; validationLayers)
            layers ~= cast (const (char)*) l;

        createInfo.enabledLayerCount = cast (uint) layers.length;
        createInfo.ppEnabledLayerNames = &layers [0];
    }
    else
    {
        createInfo.enabledLayerCount = 0;
    }

    vkAssert (vkCreateInstance (&createInfo, null, &instance),
              "Failed to create an instance");

    loadInstanceLevelFunctions (instance);
}

private void setupDebugCallback ()
{
    debug
    {
        VkDebugReportCallbackCreateInfoEXT createInfo = {};
        createInfo.flags = VK_DEBUG_REPORT_ERROR_BIT_EXT | VK_DEBUG_REPORT_WARNING_BIT_EXT;
        createInfo.pfnCallback = assumeNoGC (&vulkanDebugCallback);

        vkAssert (createDebugReportCallbackEXT (instance, &createInfo, null, &debugCallback),
                "Failed to create a debug report callback");
    }
}

private static VkResult createDebugReportCallbackEXT (VkInstance instance,
                                               const VkDebugReportCallbackCreateInfoEXT* pCreateInfo,
		                                       const VkAllocationCallbacks* pAllocator, VkDebugReportCallbackEXT* pCallback)
{
	auto func = cast (PFN_vkCreateDebugReportCallbackEXT)
                vkGetInstanceProcAddr (instance, "vkCreateDebugReportCallbackEXT");
    
	if (func)
		return func (instance, pCreateInfo, pAllocator, pCallback);
	else
		return VK_ERROR_EXTENSION_NOT_PRESENT;
}

private static void destroyDebugReportCallbackEXT (VkInstance instance, VkDebugReportCallbackEXT callback,
                                            const VkAllocationCallbacks* pAllocator)
{
	auto func = cast (PFN_vkDestroyDebugReportCallbackEXT)
                vkGetInstanceProcAddr (instance, "vkDestroyDebugReportCallbackEXT");

	if (func)
		func (instance, callback, pAllocator);
}

private bool checkValidationLayerSupport ()
{
    uint layerCount;
    vkEnumerateInstanceLayerProperties (&layerCount, null);

    if (!layerCount)
        return false;

    VkLayerProperties [] availableLayers;
    availableLayers.length = layerCount;
    vkEnumerateInstanceLayerProperties (&layerCount, availableLayers.ptr);

    foreach (validationLayer; validationLayers)
    {
        bool layerFound;

        foreach (availableLayer; availableLayers)
        {
            string avla = cast (string) availableLayer.layerName;

            if (strcmp (validationLayer.ptr, avla.ptr) == 0)
            {
                layerFound = true;
                break;
            }
        }

        if (!layerFound)
            return false;
    }

    return true;
}

private void mainLoop ()
{
    while (!window.shouldClose)
    {
        auto startTime = MonoTime.currTime;
        window.pollEvents ();
        drawFrame ();
        auto endTime = MonoTime.currTime;

        auto frame = endTime - startTime;
        float dt = frame.total!"hnsecs" * 0.0000001;
        writeln (cast (long) (1.0f / dt));
    }

    vkDeviceWaitIdle (device);
}

private void drawFrame ()
{
    vkWaitForFences (device, 1, &inFlightFences [currentFrame], VK_TRUE, uint.max);
    vkResetFences (device, 1, &inFlightFences [currentFrame]);

    uint imageIndex;
    VkResult result = vkAcquireNextImageKHR (device, swapChain,
                                             uint.max,
                                             imageAvailableSemaphores
                                             [currentFrame],
                                             VK_NULL_HANDLE,
                                             &imageIndex);

    if (result == VK_ERROR_OUT_OF_DATE_KHR)
    {
        recreateSwapCain ();
        return;
    }
    else if (result != VK_SUCCESS && result != VK_SUBOPTIMAL_KHR)
    {
        throw new Exception ("Failed to acquire swap chain image.");
    }

    updateUniformBuffer ();

    VkSubmitInfo submitInfo = {};

    VkSemaphore [1] waitSemaphores = [imageAvailableSemaphores [currentFrame]];

    VkPipelineStageFlags [1] waitStages = [VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT];
    
    submitInfo.waitSemaphoreCount = 1;
    submitInfo.pWaitSemaphores = &waitSemaphores [0];
    submitInfo.pWaitDstStageMask = &waitStages [0];
    submitInfo.commandBufferCount = 1;
    submitInfo.pCommandBuffers = &commandBuffers [imageIndex];

    VkSemaphore [1] signalSemaphores = [renderFinishedSemaphores [currentFrame]];

    submitInfo.signalSemaphoreCount = 1;
    submitInfo.pSignalSemaphores = &signalSemaphores [0];

    vkAssert (vkQueueSubmit (graphicsQueue, 1, &submitInfo, inFlightFences [currentFrame]),
              "Failed to submit a queue");

    VkPresentInfoKHR presentInfo = {};
    presentInfo.waitSemaphoreCount = 1;
    presentInfo.pWaitSemaphores = &signalSemaphores [0];

    VkSwapchainKHR [1] swapChains = [swapChain];

    presentInfo.swapchainCount = 1;
    presentInfo.pSwapchains = &swapChains [0];
    presentInfo.pImageIndices = &imageIndex;

    result = vkQueuePresentKHR (presentQueue, &presentInfo);

    if (result == VK_ERROR_OUT_OF_DATE_KHR || result == VK_SUBOPTIMAL_KHR || window.frameBufferResized)
    {
        recreateSwapCain ();
        window.frameBufferResized = false;
    }
    else if (result != VK_SUCCESS)
    {
        throw new Exception ("Failed to present swap chain image.");
    }

    currentFrame = (currentFrame + 1) % maxFramesInFlight;
}

private void cleanupSwapChain ()
{
    foreach (framebuffer; swapChainFramebuffers)
        vkDestroyFramebuffer (device, framebuffer, null);

    vkFreeCommandBuffers (device, commandPool, cast (uint) commandBuffers.length, &commandBuffers [0]);

    vkDestroyPipeline (device, graphicsPipeline, null);

    vkDestroyPipelineLayout (device, pipelineLayout, null);

    vkDestroyRenderPass (device, renderPass, null);

    foreach (imageView; swapChainImageViews)
        vkDestroyImageView (device, imageView, null);

    vkDestroySwapchainKHR (device, swapChain, null);
}

private void cleanup ()
{
    cleanupSwapChain ();

    vkDestroyDescriptorSetLayout (device, descriptorSetLayout, null);

    for (int i; i < swapChainImages.length; i++)
    {
        vkDestroyBuffer (device, uniformBuffers [i], null);
        vkFreeMemory (device, uniformBuffersMemory [i], null);
    }

    vkDestroyBuffer (device, indexBuffer, null);
    vkFreeMemory (device, indexBufferMemory, null);

    vkDestroyBuffer (device, vertexBuffer, null);
    vkFreeMemory (device, vertexBufferMemory, null);

    for (int i; i < maxFramesInFlight; i++)
    {
        vkDestroySemaphore (device, renderFinishedSemaphores [i], null);
        vkDestroySemaphore (device, imageAvailableSemaphores [i], null);
        vkDestroyFence (device, inFlightFences [i], null);
    }

    vkDestroyCommandPool (device, commandPool, null);

    vkDestroyDevice (device, null);

    debug
        destroyDebugReportCallbackEXT (instance, debugCallback, null);

    vkDestroySurfaceKHR (instance, surface, null);
    vkDestroyInstance (instance, null);

    window.destroy ();
}

private auto assumeNoGC (T) (T t) nothrow if (isFunctionPointer!T || isDelegate!T)
{
	enum attrs = functionAttributes!T | FunctionAttribute.nogc;
	return cast (SetFunctionAttributes! (T, functionLinkage!T, attrs)) t;
}

private SwapChainSupportDetails querySwapChainSupport (VkPhysicalDevice device)
{
    SwapChainSupportDetails details;

    vkGetPhysicalDeviceSurfaceCapabilitiesKHR (device, surface, &details.capabilities);

    uint formatCount;
    vkGetPhysicalDeviceSurfaceFormatsKHR (device, surface, &formatCount, null);

    if (formatCount != 0)
    {
        details.formats.length = formatCount;
        vkGetPhysicalDeviceSurfaceFormatsKHR (device, surface, &formatCount, &details.formats [0]);
    }

    uint presentModeCount;
    vkGetPhysicalDeviceSurfacePresentModesKHR (device, surface, &presentModeCount, null);

    if (presentModeCount != 0)
    {
        details.presentModes.length = presentModeCount;
        vkGetPhysicalDeviceSurfacePresentModesKHR (device, surface, &presentModeCount, &details.presentModes [0]);
    }

    return details;
}

private VkSurfaceFormatKHR chooseSwapSurfaceFormat (VkSurfaceFormatKHR [] availableFormats)
{
    if (availableFormats.length == 1 && availableFormats [0].format == VK_FORMAT_UNDEFINED)
    {
        VkSurfaceFormatKHR format =
        {
            format: VK_FORMAT_B8G8R8_UNORM,
            colorSpace: VK_COLOR_SPACE_SRGB_NONLINEAR_KHR
        };

        return format;
    }

    foreach (availableFormat; availableFormats)
    {
        if (availableFormat.format == VK_FORMAT_B8G8R8_UNORM &&
        availableFormat.colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR)
            return availableFormat;
    }

    return availableFormats [0];
}

private VkPresentModeKHR choosePresentMode (VkPresentModeKHR [] availablePresentModes)
{
    VkPresentModeKHR bestMode = VK_PRESENT_MODE_FIFO_KHR;

    foreach (availablePresentMode; availablePresentModes)
    {
        if (availablePresentMode == VK_PRESENT_MODE_MAILBOX_KHR)
            return availablePresentMode;
        else if (availablePresentMode == VK_PRESENT_MODE_IMMEDIATE_KHR)
            bestMode = availablePresentMode;
    }

    return bestMode;
}

private VkExtent2D chooseSwapExtent (VkSurfaceCapabilitiesKHR capabilities)
{
    if (capabilities.currentExtent.width != uint.max)
        return capabilities.currentExtent;
    else
    {
        int ewidth;
        int eheight;
        window.getFramebufferSize (&ewidth, &eheight);

        VkExtent2D actualExtent = {};
        actualExtent.width = width;
        actualExtent.height = height;

        actualExtent.width = max (capabilities.minImageExtent.width,
                                  min (capabilities.maxImageExtent.width, actualExtent.width));
        actualExtent.height = max (capabilities.minImageExtent.height,
                                   min (capabilities.maxImageExtent.height, actualExtent.height));

        return actualExtent;
    }
}

struct QueueFamilyIndices
{
    int graphicsFamily = -1;
    int presentFamily = -1;

    bool isComplete ()
    {
        return graphicsFamily >= 0 && presentFamily >= 0;
    }
}

struct SwapChainSupportDetails
{
    VkSurfaceCapabilitiesKHR capabilities;
    VkSurfaceFormatKHR [] formats;
    VkPresentModeKHR [] presentModes;
}

struct Vertex
{
   Vector2 position;
   Vector3 color;

   static VkVertexInputBindingDescription getBindingDescription ()
   {
       VkVertexInputBindingDescription bindingDescription = {};

        bindingDescription.binding = 0;
        bindingDescription.stride = Vertex.sizeof;
        bindingDescription.inputRate = VK_VERTEX_INPUT_RATE_VERTEX;

       return bindingDescription;
   }

   static VkVertexInputAttributeDescription [2] getAttributeDescriptions ()
   {
       VkVertexInputAttributeDescription [2] attributeDescriptions;

        attributeDescriptions [0].binding = 0;
        attributeDescriptions [0].location = 0;
        attributeDescriptions [0].format = VK_FORMAT_R32G32_SFLOAT;
        attributeDescriptions [0].offset = position.offsetof;

        attributeDescriptions [1].binding = 0;
        attributeDescriptions [1].location = 1;
        attributeDescriptions [1].format = VK_FORMAT_R32G32B32_SFLOAT;
        attributeDescriptions [1].offset = color.offsetof;

       return attributeDescriptions;
   }
}

struct UniformBufferObject
{
    Matrix4x4 model;
    Matrix4x4 view;
    Matrix4x4 projection;
}