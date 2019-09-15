import cosmomyst.vulkan.device;
import cosmomyst.vulkan.surface;
import cosmomyst.vulkan.instance;
import cosmomyst.vulkan.presenter;
import cosmomyst.vulkan.pipeline;
import erupted;

void main ()
{
	import std.stdio : readln;
	import cosmomyst.core : XCBWindow;

    XCBWindow window = new XCBWindow (400, 400);

	Instance instance = new Instance ();
	VkSurfaceKHR surface = createSurface (instance.vkInstance, window);
	Device device = new Device (instance.vkInstance, surface, 400, 400);
	Presenter presenter = new Presenter (device);

	GraphicsPipeline graphicsPipeline = new GraphicsPipeline (device);

	while (window.open)
	{
		window.pollEvents ();
	}

	graphicsPipeline.cleanup ();
	presenter.cleanup ();
	device.cleanup ();
	vkDestroySurfaceKHR (instance.vkInstance, surface, null);
	instance.cleanup ();
}
