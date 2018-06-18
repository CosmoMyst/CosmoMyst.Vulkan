using System;
using System.Runtime.InteropServices;

using SharpVk.Glfw;

using SharpVulkan;

using MathNet;
using MathNet.Numerics.LinearAlgebra;

namespace Vulkan.Engine
{
    public class Program
    {
        private const int WindowWidth = 800;
        private const int WindowHeight = 600;

        private const bool enableValidationLayers = true;

        private WindowHandle window;
        
        private Instance instance;

        private static void Main ()
        {
            Program program = new Program ();

            try
            {
                program.Run ();
            }
            catch (Exception e)
            {
                Console.WriteLine (e);
            }
        }

        public void Run ()
        {
            InitWindow ();
            InitVulkan ();
            MainLoop ();
            Cleanup ();
        }

        private void InitWindow ()
        {
            Glfw3.Init ();

            // Glfw3.WindowHint (Glfw3., false);
            // Glfw3.WindowHint (Glfw3.Hint.Resizable, false);
            // TODO: No clue how to do this with my GLFW bindings

            window = Glfw3.CreateWindow (WindowWidth, WindowHeight, "Vulkan", IntPtr.Zero, IntPtr.Zero);
        }

        private void InitVulkan ()
        {
            CreateInstance ();
        }

        private void MainLoop ()
        {
            while (!Glfw3.WindowShouldClose (window))
                Glfw3.PollEvents ();
        }

        private void Cleanup ()
        {
            // Glfw3.Destroy (window);
            // TODO: No clue how to do this

            unsafe
            {
                instance.Destroy ();
            }

            Glfw3.Terminate ();
        }

        private unsafe void CreateInstance ()
        {
            IntPtr appName = Marshal.StringToHGlobalUni("Vulkan");
            IntPtr engineName = Marshal.StringToHGlobalUni("No Engine");

            string[] extensions = Glfw3.GetRequiredInstanceExtensions();

            IntPtr[] enabledExtensionNames = new IntPtr[extensions.Length];

            try
            {
                ApplicationInfo appInfo = new ApplicationInfo
                {
                    StructureType = StructureType.ApplicationInfo,
                    ApplicationName = appName,
                    ApplicationVersion = 1,
                    EngineName = engineName,
                    EngineVersion = 1,
                    ApiVersion = SharpVulkan.Vulkan.ApiVersion
                };

                for (int i = 0; i < extensions.Length; i++)
                    enabledExtensionNames[i] = Marshal.StringToHGlobalAnsi(extensions[i]);

                fixed (void* enabledExtensionNamesPointer = &enabledExtensionNames[0])
                {
                    InstanceCreateInfo createInfo = new InstanceCreateInfo
                    {
                        StructureType = StructureType.InstanceCreateInfo,
                        ApplicationInfo = new IntPtr(&appInfo),
                        EnabledExtensionCount = (uint)extensions.Length,
                        EnabledExtensionNames = new IntPtr(enabledExtensionNamesPointer),
                        EnabledLayerCount = 0
                    };

                    instance = SharpVulkan.Vulkan.CreateInstance(ref createInfo);
                }
            }
            finally
            {
                Marshal.FreeHGlobal(appName);
                Marshal.FreeHGlobal(engineName);

                for (int i = 0; i < extensions.Length; i++)
                    Marshal.FreeHGlobal(enabledExtensionNames[i]);
            }
        }

        // private bool CheckValidationLayerSupport ()
        // {
        //     UInt32 layerCount;
        //     LayerProperties [] properties = SharpVulkan.Vulkan.InstanceLayerProperties;

        //     IntPtr[] validationLayers = new[]
        //     {
        //         Marshal.StringToHGlobalAnsi("VK_LAYER_LUNARG_standard_validation")
        //     };

        //     try
        //     {
        //         foreach (string layerName in validationLayers)
        //         {
                    
        //         }
        //     }
        //     finally
        //     {
        //         foreach (IntPtr s in validationLayers)
        //         {
        //             Marshal.FreeHGlobal (s);
        //         }
        //     }
        // }
    }
}
