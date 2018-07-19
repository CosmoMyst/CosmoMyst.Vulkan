module monomyst.vulkan.window;

import erupted;
import derelict.glfw3;
import erupted.vulkan_lib_loader;
import monomyst.vulkan.vk_helpers;

mixin DerelictGLFW3_VulkanBind;

package class Window
{
    private GLFWwindow* window;

    bool frameBufferResized;

    @property int shouldClose () { return glfwWindowShouldClose (window); }

    string title;
    int width;
    int height;

    this (string title, int width, int height)
    {
        import std.string : toStringz;

        DerelictGLFW3.load ();

        DerelictGLFW3_loadVulkan ();

        glfwInit ();

        glfwWindowHint (GLFW_CLIENT_API, GLFW_NO_API);

        window = glfwCreateWindow (width, height, title.toStringz, null, null);

        this.title = title;
        this.width = width;
        this.height = height;
    }

    string [] getRequiredExtensions ()
    {
        import std.conv : to;

        string [] extensions;

        uint glfwExtensionCount;
        const char** glfwExtensions = glfwGetRequiredInstanceExtensions (&glfwExtensionCount);

        extensions.length = glfwExtensionCount;

        for (int i; i < glfwExtensionCount; i++)
        {
            extensions [i] = glfwExtensions [i].to!string;
        }

        debug
            extensions ~= VK_EXT_DEBUG_REPORT_EXTENSION_NAME;

        return extensions;
    }

    void setWindowUserPointer (void* ptr)
    {
        glfwSetWindowUserPointer (window, ptr);
    }

    void pollEvents ()
    {
        glfwPollEvents ();
    }

    void getFramebufferSize (int* width, int* height)
    {
        glfwGetFramebufferSize (window, width, height);
    }

    void waitEvents ()
    {
        glfwWaitEvents ();
    }

    void createSurface (VkInstance instance, VkSurfaceKHR* surface)
    {
        vkAssert (glfwCreateWindowSurface (instance, window, null, surface),
                  "Failed to create a window surface");
    }

    void setFramebufferSizeCallback (GLFWframebuffersizefun callback) nothrow
    {
        glfwSetFramebufferSizeCallback (window, callback);
    }

    void destroy ()
    {
        glfwDestroyWindow (window);
        glfwTerminate ();
    }
}