namespace MonoMyst.Vulkan
{
    public class QueueFamilyIndices
    {
        public int GraphicsFamily = -1;
        public int PresentFamily = -1;

        public bool IsComplete () => GraphicsFamily >= 0 && PresentFamily >= 0;
    }
}
