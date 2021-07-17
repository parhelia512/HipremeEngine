module view.bitmaptestscene;
import implementations.renderer;
import def.debugging.log;
import view.scene;


class BitmapTestScene : Scene
{
    HipBitmapText txt;
    this()
    {
        txt = new HipBitmapText();
        txt.setBitmapFont(HipBitmapFont.fromFile("assets/fonts/arial.fnt"));
        txt.setText("TESTE");
        logln(txt.font.atlasTexturePath);
        logln(txt.getVertices());
    }

    override void render()
    {
        HipRenderer.setColor(0,0,0,255);
        HipRenderer.clear();
        txt.render();
    }
}