using System;

using MonoMyst.Vulkan.Utilities;

using Glfw3 = MonoMyst.Glfw.Glfw;
using Window = MonoMyst.Glfw.Glfw.Window;

namespace MonoMyst.Vulkan
{
    public class Game : IDisposable
    {
        private const int Width = 800;
        private const int Height = 600;

        private Window window;

        private VulkanInstance instance;

        public void Run ()
        {
            InitWindow ();

            InitVulkan ();

            Update ();
        }

        private void InitWindow ()
        {
            Glfw3.Init ();
            Glfw3.WindowHint (Glfw3.Hint.Resizable, false);
            Glfw3.WindowHint (Glfw3.Hint.ClientApi, false);

            window = Glfw3.CreateWindow (Width, Height, "MonoMyst.Vulkan");
        }

        private void InitVulkan ()
        {
            instance = new VulkanInstance ("MonoMyst.Vulkan");
            instance.PrintAvailableExtensions ();
            instance.PrintGlfwExtensions ();
            if (instance.CheckRequiredExtensionsPresent ())
                Logger.WriteLine ("All required extensions are present.", ConsoleColor.Green);
            else
                Logger.WriteLine ("Not all required extensions are present.", ConsoleColor.Red);
        }

        private void Update ()
        {
            while (Glfw3.WindowShouldClose (window) == false)
                Glfw3.PollEvents ();
        }

        public void Dispose ()
        {
            Glfw3.DestroyWindow (window);

            Glfw3.Terminate ();
        }
    }
}
