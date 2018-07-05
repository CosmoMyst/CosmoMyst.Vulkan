module monomyst.vulkan;

import derelict.vulkan;
import derelict.glfw3.glfw3;
import std.file : getcwd;
import std.string : format;

GLFWwindow* window;

public void run ()
{
    initWindow ();
    initVulkan ();
    mainLoop ();
    cleanup ();
}

void initWindow ()
{
	DerelictGLFW3.load (format ("%s/libs/libglfw.so.3.2", getcwd));

    glfwInit ();

    glfwWindowHint (GLFW_CLIENT_API, GLFW_NO_API);
    glfwWindowHint (GLFW_RESIZABLE, GLFW_FALSE);

    window = glfwCreateWindow (800, 600, "MonoMyst.Vulkan", null, null);
}

void initVulkan ()
{
	DerelictVulkan.load (format ("%s/libs/libvulkan.so.1", getcwd));
}

void mainLoop ()
{
    while (!glfwWindowShouldClose (window))
        glfwPollEvents ();
}

void cleanup ()
{
    glfwDestroyWindow (window);
    glfwTerminate ();
}