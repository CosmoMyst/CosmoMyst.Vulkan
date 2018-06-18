using System;
using System.Runtime.InteropServices;

namespace SharpVk.Glfw
{
    public struct VideoModePointer
    {
        private IntPtr pointer;

        public VideoMode Value => Marshal.PtrToStructure<VideoMode>(this.pointer);

        public IntPtr RawPointer => this.pointer;
    }
}
