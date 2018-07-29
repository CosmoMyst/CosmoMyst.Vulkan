import monomyst.vulkan;

void main ()
{
	Window window = new Window (800, 600, "MonoMyst.Vulkan");

	while (window.shouldClose == false)
	{
		window.pollEvents ();
	}
}