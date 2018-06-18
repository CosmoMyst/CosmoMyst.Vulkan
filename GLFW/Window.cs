using System;

namespace SharpVk.Glfw
{
    /// <summary>
    /// Represents an instance of a GLFW3 Window.
    /// </summary>
    public class Window
    {
        internal readonly WindowHandle handle;

        public Window(int width, int height, string title)
        {
            this.handle = Glfw3.CreateWindow(width, height, title, IntPtr.Zero, IntPtr.Zero);
        }

        public bool ShouldClose => Glfw3.WindowShouldClose(this.handle);
    }
}
