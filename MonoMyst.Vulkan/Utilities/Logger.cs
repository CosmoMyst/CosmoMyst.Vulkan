using System;

namespace MonoMyst.Vulkan.Utilities
{
    public class Logger
    {
        public static void WriteLine (string text, ConsoleColor color)
        {
            ConsoleColor prevColor = Console.ForegroundColor;
            Console.ForegroundColor = color;
            Console.WriteLine (text);
            Console.ForegroundColor = prevColor;
        }
    }
}
