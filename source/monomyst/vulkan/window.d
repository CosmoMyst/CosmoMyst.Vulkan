module monomyst.vulkan.window;

import erupted;
import derelict.glfw3;
import erupted.vulkan_lib_loader;
import monomyst.vulkan.vk_helpers;

mixin DerelictGLFW3_VulkanBind;

/++
    Wrapper of the GLFWwindow class.
+/
package class Window
{
    private GLFWwindow* window;

    /++
        Is the framebuffer resized. 

        Used to check when the framebuffer is resized to recreate the swapchain.
    +/
    bool frameBufferResized;

    /++
        Checks the close flag of the window.

        Returns: The value of the close flag.

        Errors: Possible errors include [GLFW_NOT_INITIALIZED](http://www.glfw.org/docs/latest/group__errors.html#ga2374ee02c177f12e1fa76ff3ed15e14a).

        Examples:
        --------------------
        while (!window.shouldClose)
            window.pollEvents ();
        --------------------
    +/
    @property int shouldClose () { return glfwWindowShouldClose (window); }

    /++
        The title of the window.
    +/
    string title;

    /++
        The width of the window.
    +/
    int width;

    /++
        The height of the window.
    +/
    int height;

    /++
        Creates a new window with a tile, width and height.

        Params:
            title =     The title of the window
            width =     Width of the window, has to be positive
            height =    Height of the window, has to be positive
    +/
    this (string title, int width, int height)
    in
    {
        assert (width >= 0, "Width has to be positive");
        assert (height >= 0, "Height has to be positive");
    }
    do
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

    /++
        Get the of names of Vulkan instance extensions required by GLFW for creating Vulkan surfaces.
    +/
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

    /++
        This function sets the user-defined pointer of the specified window.
        The current value is retained until the window is destroyed.
        The initial value is NULL.
    +/
    void setWindowUserPointer (void* ptr)
    {
        glfwSetWindowUserPointer (window, ptr);
    }

    /++
        This function processes only those events that are already in the event queue and then returns immediately.
        Processing events will cause the window and input callbacks associated with those events to be called.
    
        On some platforms, a window move, resize or menu operation will cause event processing to block.
        This is due to how event processing is designed on those platforms.
        You can use the [window refresh callback](http://www.glfw.org/docs/latest/window_guide.html#window_refresh) to redraw the contents of your window when necessary during such operations.
    +/
    void pollEvents ()
    {
        glfwPollEvents ();
    }

    /++
        This function retrieves the size, in pixels, of the framebuffer of the specified window.
        If you wish to retrieve the size of the window in screen coordinates, see [glfwGetWindowSize](http://www.glfw.org/docs/latest/group__window.html#gaeea7cbc03373a41fb51cfbf9f2a5d4c6).
    +/
    void getFramebufferSize (int* width, int* height)
    {
        glfwGetFramebufferSize (window, width, height);
    }

    /++
        This function puts the calling thread to sleep until at least one event is available in the event queue.
        Once one or more events are available, it behaves exactly like [glfwPollEvents](http://www.glfw.org/docs/latest/group__window.html#ga37bd57223967b4211d60ca1a0bf3c832), i.e. the events in the queue are processed and the function then returns immediately.
        Processing events will cause the window and input callbacks associated with those events to be called.
    +/
    void waitEvents ()
    {
        glfwWaitEvents ();
    }

    /++
        This function creates a Vulkan surface for the specified window.
    +/
    void createSurface (VkInstance instance, VkSurfaceKHR* surface)
    {
        vkAssert (glfwCreateWindowSurface (instance, window, null, surface),
                  "Failed to create a window surface");
    }

    /++
        This function sets the framebuffer resize callback of the specified window, which is called when the framebuffer of the specified window is resized.
    +/
    void setFramebufferSizeCallback (GLFWframebuffersizefun callback) nothrow
    {
        glfwSetFramebufferSizeCallback (window, callback);
    }

    /++
        Destroys the window and terminates glfw.
    +/
    void destroy ()
    {
        glfwDestroyWindow (window);
        glfwTerminate ();
    }
}