using System;

namespace MonoMyst.Vulkan
{
    public class Program
    {
        private static void Main ()
        {
            using (Game game = new Game ())
                game.Run ();
                    
            Console.ReadKey ();
        }
    }
}
