import monomyst.vulkan.instance;

void main ()
{
	import std.stdio : readln;
	import monomyst.core : Window;

    Window window = new Window ();

	Instance instance = new Instance ();

	while (!window.shouldClose)
	{
		window.pollEvents ();
	}
}