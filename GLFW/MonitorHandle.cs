using System;

namespace SharpVk.Glfw
{
    public struct MonitorHandle
    {
        internal MonitorHandle(IntPtr handle)
        {
            this.handle = handle;
        }

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
