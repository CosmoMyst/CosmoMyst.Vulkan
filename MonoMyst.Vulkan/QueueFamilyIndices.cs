namespace MonoMyst.Vulkan
{
    public class QueueFamilyIndices
    {
        public int GraphicsFamily = -1;

        public bool IsComplete () => GraphicsFamily >= 0;
    }
}
