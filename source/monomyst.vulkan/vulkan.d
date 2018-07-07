module monomyst.vulkan;

import erupted;
import erupted.vulkan_lib_loader;
import derelict.glfw3;
import std.file : getcwd;
import std.string;
import std.stdio;
import std.exception;
import std.conv;

mixin DerelictGLFW3_VulkanBind;

private GLFWwindow* window;
private VkInstance instance;

void run ()
{
    initWindow ();
    initVulkan ();
    mainLoop ();
    cleanup ();
}

private void initWindow ()
{
	DerelictGLFW3.load ();

    DerelictGLFW3_loadVulkan ();

    glfwInit ();

    glfwWindowHint (GLFW_CLIENT_API, GLFW_NO_API);
    glfwWindowHint (GLFW_RESIZABLE, GLFW_FALSE);

    window = glfwCreateWindow (800, 600, "MonoMyst.Vulkan", null, null);
}

private void enforceVk (VkResult result)
{
    enforce (result == VkResult.VK_SUCCESS, result.to!string);
}

private void initVulkan ()
{
    loadGlobalLevelFunctions ();

    VkApplicationInfo appInfo = {
        pApplicationName: "MonoMyst.Vulkan",
        applicationVersion: VK_MAKE_VERSION (1, 0, 0),
        pEngineName: "MonoMyst",
        engineVersion: VK_MAKE_VERSION (1, 0, 0),
        apiVersion: VK_MAKE_VERSION (1, 0, 2)
    };

    VkInstanceCreateInfo createInfo = 
    {
        pApplicationInfo: &appInfo
    };

    uint glfwExtensionCount;
    const char** glfwRequiredExtensions = glfwGetRequiredInstanceExtensions (&glfwExtensionCount);

    createInfo.enabledExtensionCount = glfwExtensionCount;
    createInfo.ppEnabledExtensionNames = glfwRequiredExtensions;
    createInfo.enabledLayerCount = 0;

    uint extensionCount;
    const (char)* w = "".toStringz;
    vkEnumerateInstanceExtensionProperties (w, &extensionCount, null);

    VkExtensionProperties [] extensions = new VkExtensionProperties [extensionCount];
    vkEnumerateInstanceExtensionProperties (w, &extensionCount, extensions.ptr);

    writeln ("Available extensions (", extensions.length, "):");
    foreach (ex; extensions)
        writefln (ex.extensionName);
    
    vkCreateInstance (&createInfo, null, &instance).enforceVk;

    scope (exit)
    {
        if (instance != VK_NULL_HANDLE)
            vkDestroyInstance (instance, null);
    }

    loadInstanceLevelFunctions (instance);
}

private void mainLoop ()
{
    while (!glfwWindowShouldClose (window))
        glfwPollEvents ();
}

private void cleanup ()
{
    glfwDestroyWindow (window);
    glfwTerminate ();
}