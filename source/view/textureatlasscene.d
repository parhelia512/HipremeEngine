/*
Copyright: Marcelo S. N. Mancini (Hipreme|MrcSnm), 2018 - 2021
License:   [https://creativecommons.org/licenses/by/4.0/|CC BY-4.0 License].
Authors: Marcelo S. N. Mancini

	Copyright Marcelo S. N. Mancini 2018 - 2021.
Distributed under the CC BY-4.0 License.
   (See accompanying file LICENSE.txt or copy at
	https://creativecommons.org/licenses/by/4.0/
*/
module view.textureatlasscene;
import hiprenderer;
import graphics.g2d.textureatlas;
import graphics.g2d.spritebatch;
import graphics.g2d.animation;
import view;

class TextureAtlasScene : Scene
{
    TextureAtlas atlas;
    HipAnimation emerald;
    HipSpriteBatch batch;
    this()
    {
        atlas = TextureAtlas.readJSON("graphics/atlases/UI.json");
        batch = new HipSpriteBatch();
        emerald = HipAnimation.fromAtlas(atlas, "emerald", 12, true);
    }
    override void update(float dt)
    {
        emerald.update(dt);
    }

    override void render()
    {
        batch.camera.setScale(4,4);
        batch.begin();
        batch.draw(emerald.getCurrentFrame().region, 0, 0);
        batch.end();
    }
}