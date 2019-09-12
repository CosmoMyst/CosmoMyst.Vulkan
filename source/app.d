import cosmomyst.vulkan.device;
import cosmomyst.vulkan.instance;
import cosmomyst.vulkan.presenter;

void main ()
{
	import std.stdio : readln;
	import cosmomyst.core : XCBWindow;

    XCBWindow window = new XCBWindow (400, 400);

	Instance instance = new Instance ();
	Presenter presenter = new Presenter (instance.vkInstance, window);
	Device device = new Device (instance.vkInstance, presenter.vkSurface, 400, 400);

	while (window.open)
	{
		window.pollEvents ();
	}

	device.cleanup ();
	presenter.cleanup ();
	instance.cleanup ();
}
