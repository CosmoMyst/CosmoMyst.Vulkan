using System;
using System.Linq;

using MonoMyst.Vulkan.Utilities;

using SharpVulkan;

using Vk = SharpVulkan;
using Glfw3 = MonoMyst.Glfw.Glfw;
using Window = MonoMyst.Glfw.Glfw.Window;

namespace MonoMyst.Vulkan
{
    public class Game : IDisposable
    {
#if DEBUG
        private const bool EnableDebug = true;
#else
        private const bool EnableDebug = false;
#endif

        public static readonly string [] ValidationLayers = new string []
        {
            VulkanConstants.VK_STANDARD_VALIDATION
        };

        private const int Width = 800;
        private const int Height = 600;

        private Window window;

        private VulkanInstance instance;
        private Device device;
        private Presenter presenter;

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
            if (EnableDebug && !CheckValidationLayerSupport ())
                Logger.WriteLine ("Validation layers are requested but they're not available.", ConsoleColor.Red);
            else
                Logger.WriteLine ("All requested validation layers are available.", ConsoleColor.Green);

            instance = new VulkanInstance ("MonoMyst.Vulkan", EnableDebug);
            presenter = instance.CreatePresenter (window);
            device = instance.CreateDevice (presenter.Surface);
        }

        private void Update ()
        {
            while (Glfw3.WindowShouldClose (window) == false)
                Glfw3.PollEvents ();
        }

        private bool CheckValidationLayerSupport ()
        {
            LayerProperties [] layerProperties = Vk.Vulkan.InstanceLayerProperties;

            foreach (string layerName in ValidationLayers)
            {
                string [] props = VulkanUtilities.LayerPropertiesToString (layerProperties);

                if (props.Contains (layerName) == false) return false;
            }

            return true;
        }

        public unsafe void Dispose ()
        {
            device.Dispose ();

            presenter.Dispose ();

            instance.Dispose ();

            Glfw3.DestroyWindow (window);

            Glfw3.Terminate ();
        }
    }
}
