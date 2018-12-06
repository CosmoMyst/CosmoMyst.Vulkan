import monomyst.vulkan.device;
import monomyst.vulkan.instance;
import monomyst.vulkan.presenter;

void main ()
{
	import std.stdio : readln;
	import monomyst.core : Window;

    Window window = new Window ();

	Instance instance = new Instance ();
	Presenter presenter = new Presenter (instance.vkInstance, window);
	Device device = new Device (instance.vkInstance, presenter.vkSurface);

	while (!window.shouldClose)
	{
		window.pollEvents ();
	}

	device.cleanup ();
	presenter.cleanup ();
	instance.cleanup ();
}