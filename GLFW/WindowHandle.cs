using System;

namespace SharpVk.Glfw
{
    public struct WindowHandle
    {
        private IntPtr handle;

        public IntPtr RawHandle
        {
            get
            {
                return this.handle;
            }
        }
    }
}
