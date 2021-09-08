/*
Copyright: Marcelo S. N. Mancini, 2018 - 2021
License:   [https://opensource.org/licenses/MIT|MIT License].
Authors: Marcelo S. N. Mancini

	Copyright Marcelo S. N. Mancini 2018 - 2021.
Distributed under the MIT Software License.
   (See accompanying file LICENSE.txt or copy at
	https://opensource.org/licenses/MIT)
*/

module systems.game;
import bindbc.sdl;
import hiprenderer.renderer;
private import sdl.event.dispatcher;
private import sdl.event.handlers.keyboard;
import view;

class GameSystem
{
    /** 
     * Holds the member that generates the events as inputs
     */
    EventDispatcher dispatcher;
    KeyboardHandler keyboard;
    Scene[] scenes;
    bool hasFinished;
    float fps;

    this()
    {
        keyboard = new KeyboardHandler();
        keyboard.addKeyListener(SDLK_ESCAPE, new class Key
        {
            override void onDown(){hasFinished = true;}
            override void onUp(){}
        });
        dispatcher = new EventDispatcher(&keyboard);
        dispatcher.addOnResizeListener((uint width, uint height)
        {
            HipRenderer.width = width;
            HipRenderer.height = height;
            foreach (Scene s; scenes)
                s.onResize(width, height);
        });

        import view.testscene;
        import view.uwptest;
        Scene testscene = new TilemapTestScene();
    	testscene.init();
        scenes~= testscene;

    }

    bool update(float deltaTime)
    {
        fps = cast(float)cast(uint)(1/deltaTime);
        import std.conv:to;
        SDL_SetWindowTitle(HipRenderer.window, (to!string(fps)~" FPS\0").ptr);
        dispatcher.handleEvent();

        if(hasFinished || dispatcher.hasQuit)
            return false;
        version(Android){}
        else {keyboard.update();}
        foreach(s; scenes)
            s.update(deltaTime);

        return true;
    }
    void render()
    {
        foreach (Scene s; scenes)
            s.render();
    }
    void postUpdate()
    {
        dispatcher.postUpdate();
    }
    
    void quit()
    {
        SDL_Quit();
    }
}