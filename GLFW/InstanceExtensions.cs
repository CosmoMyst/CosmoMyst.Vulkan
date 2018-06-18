using SharpVulkan;

namespace SharpVk.Glfw
{
    /// <summary>
    /// 
    /// </summary>
    public static class InstanceExtensions
    {
        // /// <summary>
        // /// Create a Surface object for a GLFW3 window.
        // /// </summary>
        // /// <param name="instance"></param>
        // /// <param name="windowHandle"></param>
        // /// <returns></returns>
        // public unsafe static Surface CreateGlfw3Surface(this Instance instance, WindowHandle windowHandle)
        // {
        //     Result result = Glfw3.CreateWindowSurface(instance.RawHandle, windowHandle, null, out ulong surfaceHandle);

        //     if (SharpVkException.IsError(result))
        //     {
        //         throw SharpVkException.Create(result);
        //     }

        //     return Surface.CreateFromHandle(instance, surfaceHandle);
        // }

        // /// <summary>
        // /// Create a Surface object for a GLFW3 window.
        // /// </summary>
        // /// <param name="instance"></param>
        // /// <param name="window"></param>
        // /// <returns></returns>
        // public unsafe static Surface CreateGlfw3Surface(this Instance instance, Window window)
        // {
        //     Result result = Glfw3.CreateWindowSurface(instance.RawHandle, window.handle, null, out ulong surfaceHandle);

        //     if (SharpVkException.IsError(result))
        //     {
        //         throw SharpVkException.Create(result);
        //     }

        //     return Surface.CreateFromHandle(instance, surfaceHandle);
        // }
    }
}
