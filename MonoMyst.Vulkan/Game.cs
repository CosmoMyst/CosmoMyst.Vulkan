using System;

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
