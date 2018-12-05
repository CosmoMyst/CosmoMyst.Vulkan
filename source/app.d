import monomyst.vulkan.instance;
import monomyst.vulkan.device;

void main ()
{
	import std.stdio : readln;
	import monomyst.core : Window;

    Window window = new Window ();

	Instance instance = new Instance ();
	Device device = new Device (instance.vkInstance);

	while (!window.shouldClose)
	{
		window.pollEvents ();
	}
}