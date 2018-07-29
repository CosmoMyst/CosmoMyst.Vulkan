module monomyst.vulkan.window;

import derelict.sdl2.sdl;

/++
    Wrapper for a SDL2 window.
+/
public class Window
{
    private SDL_Window* window;

    /++
        Should the window close
    +/
    public bool shouldClose;

    private SDL_Event event;

    /++
        Creates a new Window class.
    +/
    public this (int width, int height, string title)
    {
        import std.string : toStringz;
        import std.stdio : writefln;

        DerelictSDL2.load ();

        if (SDL_Init (SDL_INIT_EVERYTHING) != 0)
        {
            writefln ("SDL_Init Error: %s", SDL_GetError ());
            return;
        }

        window = SDL_CreateWindow (title.toStringz,
                                   SDL_WINDOWPOS_CENTERED,
                                   SDL_WINDOWPOS_CENTERED,
                                   width,
                                   height,
                                   SDL_WINDOW_SHOWN);

        if (window == null)
        {
            writefln ("SDL_CreateWindow Error: %s", SDL_GetError ());
            SDL_Quit ();
            return;   
        }
    }

    public ~this ()
    {
        SDL_DestroyWindow (window);
        SDL_Quit ();
    }

    /++
        Polls all window events.
    +/
    public void pollEvents ()
    {
        while (SDL_PollEvent (&event))
        {
            switch (event.type)
            {
                case SDL_QUIT:
                    shouldClose = true;
                    break;
                default:
                    break;
            }
        }
    }
}