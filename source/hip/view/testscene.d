/*
Copyright: Marcelo S. N. Mancini (Hipreme|MrcSnm), 2018 - 2021
License:   [https://creativecommons.org/licenses/by/4.0/|CC BY-4.0 License].
Authors: Marcelo S. N. Mancini

	Copyright Marcelo S. N. Mancini 2018 - 2021.
Distributed under the CC BY-4.0 License.
   (See accompanying file LICENSE.txt or copy at
	https://creativecommons.org/licenses/by/4.0/
*/
module hip.view.testscene;
version(Test):

import hip.graphics.g2d.geometrybatch;
import hip.hiprenderer.shader;
import hip.hiprenderer;
import hip.hiprenderer.viewport;
import hip.view.scene;
import hip.math.utils;

class TestScene : Scene, IHipPreloadable
{
    import hip.api;
    import hip.api.audio.audiosource;

    mixin Preload;

    //Lower Level API. Not available in the Scripting API
    GeometryBatch geom;
    Shader shader;

    IHipFont smallFont;
    IHipFont bigFont;

    @Asset("sounds/pop.wav")
    __gshared IHipAudioClip pop;


    AHipAudioSource src;

    import hip.graphics.g2d.particles;
    HipParticleSystem sys;


    float x = 100, y = 100;

    override void initialize()
    {
        logg(getAssetsForPreload);
        // logg(pop is null);
        geom = new GeometryBatch(null, 5000, 5000);
        geom.setColor(HipColor.green);

        setWindowSize(HipRenderer.width, HipRenderer.height);
        src = HipAudio.getSource();
        src.clip = pop;


        smallFont = HipDefaultAssets.getDefaultFontWithSize(20);
        bigFont = HipDefaultAssets.getDefaultFontWithSize(64);

        sys = new HipParticleSystem(500);
        sys.config.colors = [HipColorStop(HipColor.red, 0), HipColorStop(HipColor(0x000000ff), 0.2)];
        sys.config.velocityYInit = ValueRange(0, -300);
        sys.setEmissionZone(100, 150, 100, 150);
    }
    override void update(float dt)
    {
        super.update(dt);
        if(HipInput.areGamepadButtonsJustPressed([HipGamepadButton.psSquare, HipGamepadButton.psTriangle]))
            logg("Button combination pressed!");

        auto v = HipInput.getAnalog(HipGamepadAnalogs.leftStick);

        x+= dt*400*v[0];
        y+= dt*400*v[1];

        if(HipInput.isMouseButtonJustReleased(HipMouseButton.left))
        {
            src.play();
            if(HipInput.isDoubleClicked(HipMouseButton.left))
                logg("Double clicked");
            else
                logg("You just clicked me!");
        }

        if(HipInput.isKeyJustPressed(HipKey.ENTER))
        {
            logg("Don't press ENTER!");
        }
        sys.update(dt);
    }

    override void render()
    {
        //////////////////////Lower Level////////////////////////
        super.render();
        geom.setColor(HipColor.red);
        geom.fillRectangle(0, 0, 200, 200);
        geom.setColor(HipColor.green);
        geom.fillRectangle(0, 0, 100, 100);
        geom.flush();


        //Use a non GC allocating string on render (String) for drawing the mousePosition
        import hip.util.string;
        float[2] mousePos = HipInput.getMousePosition();
        setFont(smallFont);
        String s = String(mousePos);
        drawText(s.toString, cast(int)mousePos[0], cast(int)mousePos[1]);

        

        ////////////////////////Higher Level////////////////////////
        setGeometryColor(HipColor.white);
        setFont(null);
        drawText("Hello World Test Scene (Default Font)", 300, 280, HipColor.white, HipTextAlign.LEFT, HipTextAlign.TOP);
        fillRectangle(cast(int)x, cast(int)y, 100, 100);

        drawText("Null Textures uses that sprite over here", 300, 480, HipColor.white, HipTextAlign.LEFT, HipTextAlign.TOP);
        fillRectangle(cast(int)x+200, cast(int)y, 100, 100);
        drawTexture(null, 300, 500);

        sys.draw();

    }
}