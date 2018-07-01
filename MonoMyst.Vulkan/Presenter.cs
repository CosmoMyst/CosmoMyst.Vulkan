using System;

using SharpVulkan;

using static MonoMyst.Glfw.Glfw;

namespace MonoMyst.Vulkan
{
    public unsafe class Presenter : IDisposable
    {
        public Surface Surface { get; private set; }

        private readonly Instance instance;
        private readonly Window window;

        public Presenter (Instance instance, Window window)
        {
            this.instance = instance;
            this.window = window;

            CreateSurface ();
        }

        private void CreateSurface () => Surface = CreateWindowSurface (instance, window);

        public void Dispose () => instance.DestroySurface (Surface);
    }
}
