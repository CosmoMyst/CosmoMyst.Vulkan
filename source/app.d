import derelict.vulkan;
import derelict.glfw3.glfw3;
import std.file : getcwd;
import std.string : format;
import monomyst.vulkan;

void main()
{
	DerelictGLFW3.load(format("%s/libs/libglfw.so.3.2", getcwd));
	DerelictVulkan.load(format("%s/libs/libvulkan.so.1", getcwd));

	run ();
}