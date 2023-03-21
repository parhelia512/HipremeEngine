module hip.graphics.g2d.renderer2d;

version(Have_bindbc_lua) version = HipremeEngineLua;

import hip.graphics.g2d.spritebatch;
import hip.graphics.g2d.tilemap;
import hip.graphics.g2d.geometrybatch;
import hip.graphics.orthocamera;
import hip.hiprenderer;
import hip.bind.interpreters;
public import hip.api.graphics.color;
public import hip.api.data.commons:IHipAssetLoadTask;
public import hip.graphics.g2d.textrenderer;
public import hip.api.renderer.viewport;

public import hip.api.data.font;

private __gshared
{
    IHipTexture defaultTexture;
    HipSpriteBatch spBatch;
    GeometryBatch geoBatch;
    HipTextRenderer textBatch;
    HipOrthoCamera camera;
    Viewport viewport;
    HipTextRenderer textRenderer;
    IHipBatch lastBatch;
    bool autoUpdateCameraAndViewport;
    float sharedDepth = 0;
}

void manageBatchChange(IHipBatch newBatch)
{
    if(lastBatch !is null && lastBatch !is newBatch)
    {
        sharedDepth+= 0.01;
        lastBatch = newBatch;
        newBatch.setCurrentDepth(sharedDepth);
    }
}


import hip.console.log;
void initialize(HipInterpreterEntry entry = HipInterpreterEntry.init, bool shouldAutoUpdateCameraAndViewport = true)
{
    autoUpdateCameraAndViewport = shouldAutoUpdateCameraAndViewport;
    hiplog("2D Renderer: Initializing viewport");
    viewport = new Viewport(0, 0, HipRenderer.width, HipRenderer.height);
    viewport.setWorldSize(HipRenderer.width, HipRenderer.height);
    viewport.setType(ViewportType.fit, HipRenderer.width, HipRenderer.height);
    HipRenderer.setViewport(viewport);
    hiplog("2D Renderer: Initializing camera");
    camera = new HipOrthoCamera();
    camera.setSize(viewport.worldWidth, viewport.worldHeight);

    hiplog("2D Renderer: Initializing spritebatch");
    spBatch = new HipSpriteBatch(camera);
    hiplog("2D Renderer: Initializing geometrybatch");
    geoBatch = new GeometryBatch(camera);
    hiplog("2D Renderer: Initializing text renderer");
    textBatch = new HipTextRenderer(camera);
    setGeometryColor(HipColorf.white);


    version(HipremeEngineLua)
    {
        hiplog("2D Renderer: sending lua functions");
        if(entry != HipInterpreterEntry.init)
        {
            sendInterpreterFunc!(renderSprites)(entry.intepreter);
            sendInterpreterFunc!(renderGeometries)(entry.intepreter);
            sendInterpreterFunc!(renderTexts)(entry.intepreter);
            sendInterpreterFunc!(setGeometryColor)(entry.intepreter);
            sendInterpreterFunc!(drawPixel)(entry.intepreter);
            sendInterpreterFunc!(drawRectangle)(entry.intepreter);
            sendInterpreterFunc!(drawTriangle)(entry.intepreter);
            sendInterpreterFunc!(fillRectangle)(entry.intepreter);
            sendInterpreterFunc!(fillEllipse)(entry.intepreter);
            sendInterpreterFunc!(drawEllipse)(entry.intepreter);
            sendInterpreterFunc!(fillTriangle)(entry.intepreter);
            sendInterpreterFunc!(drawLine)(entry.intepreter);
            sendInterpreterFunc!(drawQuadraticBezierLine)(entry.intepreter);
            // sendInterpreterFunc!(drawText)(entry.intepreter); not supported yet
        }
    }

}

/**
*   This resizes both the 2D renderer viewport and its Orthographic Camera, maintaining always the
*   correct aspect ratio
*/
void resizeRenderer2D(uint width, uint height)
{
    if(autoUpdateCameraAndViewport)
    {
        if(viewport !is null && HipRenderer.getCurrentViewport() == viewport)
            HipRenderer.setViewport(viewport);
        if(camera !is null)
            camera.setSize(viewport.worldWidth, viewport.worldHeight);
    }
}

export extern(System):


int[2] getWindowSize(){return [HipRenderer.width, HipRenderer.height];}

void setWindowSize(uint width, uint height)
{
    HipRenderer.setWindowSize(width, height);
    HipRenderer.setViewport(viewport);
    camera.setSize(cast(int)viewport.worldWidth,cast(int)viewport.worldHeight);
}
void setCameraSize(uint width, uint height){camera.setSize(width, height);}
void setViewport(Viewport v)
{
    HipRenderer.setViewport(v);
}
Viewport getCurrentViewport()
{
    import hip.util.lifetime;
    return cast(typeof(return))hipSaveRef(HipRenderer.getCurrentViewport());
}
void renderSprites()
{
    spBatch.render();
}
void setRendererErrorCheckingEnabled(bool enable)
{
    HipRenderer.setErrorCheckingEnabled(enable);
}
void renderGeometries()
{
    geoBatch.flush();
}
void renderTexts()
{
    textBatch.flush();
}
void setGeometryColor(in HipColorf color){geoBatch.setColor(color);}
void drawPixel(int x, int y, in HipColorf color = HipColorf.invalid)
{
    manageBatchChange(geoBatch);
    geoBatch.drawPixel(x, y,color);
}
void drawRectangle(int x, int y, int w, int h, in HipColorf color = HipColorf.invalid)
{
    manageBatchChange(geoBatch);
    geoBatch.drawRectangle(x,y,w,h,color);
}
void drawTriangle(int x1, int y1, int x2, int y2, int x3, int y3, in HipColorf color = HipColorf.invalid)
{
    manageBatchChange(geoBatch);
    geoBatch.drawTriangle(x1,y1,x2,y2,x3,y3,color);
}
void drawEllipse(int x, int y, int radiusW, int radiusH, int degrees = 360, in HipColorf color = HipColorf.invalid, int precision = 24)
{
    manageBatchChange(geoBatch);
    geoBatch.drawEllipse(x,y,radiusW,radiusH,degrees,color,precision);
}
void drawLine(int x1, int y1, int x2, int y2, in HipColorf color = HipColorf.invalid)
{
    manageBatchChange(geoBatch);
    geoBatch.drawLine(x1,y1,x2,y2,color);
}
void drawQuadraticBezierLine(int x0, int y0, int x1, int y1, int x2, int y2, int precision=24, in HipColorf color = HipColorf.invalid)
{
    manageBatchChange(geoBatch);
    geoBatch.drawQuadraticBezierLine(x0,y0,x1,y1,x2,y2,precision,color);
}
void fillRectangle(int x, int y, int w, int h, in HipColorf color = HipColorf.invalid)
{
    manageBatchChange(geoBatch);
    geoBatch.fillRectangle(x,y,w,h,color);
}
void fillEllipse(int x, int y, int radiusW, int radiusH = -1, int degrees = 360, in HipColorf color = HipColorf.invalid, int precision = 24)
{
    manageBatchChange(geoBatch);
    geoBatch.fillEllipse(x,y,radiusW,radiusH,degrees,color,precision);
}
void fillTriangle(int x1, int y1, int x2,  int y2, int x3, int y3, in HipColorf color = HipColorf.invalid)
{
    manageBatchChange(geoBatch);
    geoBatch.fillTriangle(x1,y1,x2,y2,x3,y3,color);
}

void drawSprite(IHipTexture texture, float[] vertices)
{
    manageBatchChange(spBatch);
    spBatch.draw(texture, vertices);
}
void drawRegion(IHipTextureRegion reg, int x, int y, int z = 0, const HipColorf color = HipColorf.white, float scaleX = 1, float scaleY = 1, float rotation = 0)
{
    manageBatchChange(spBatch);
    spBatch.draw(reg, x, y, z, color, scaleX, scaleY, rotation);
}
void drawMap(IHipTilemap map)
{
    manageBatchChange(spBatch);
    map.render(spBatch, false);
}

void drawTexture(IHipTexture texture, int x, int y, int z = 0, const HipColorf color = HipColorf.white, float scaleX = 1, float scaleY = 1, float rotation = 0)
{
    manageBatchChange(spBatch);
    spBatch.draw(texture, x, y, z, color, scaleX, scaleY, rotation);
}


public import hip.util.data_structures : Array2D, Array2D_GC;
Array2D_GC!IHipTextureRegion cropSpritesheet(
    IHipTexture t,
    uint frameWidth, uint frameHeight,
    uint width, uint height,
    uint offsetX, uint offsetY,
    uint offsetXPerFrame, uint offsetYPerFrame
)
{
    import hip.assets.texture;
    import hip.util.lifetime;
    return cast(typeof(return))hipSaveRef(HipTextureRegion.cropSpritesheet(t, 
        frameWidth, frameHeight, 
        width, height, 
        offsetX, offsetY, 
        offsetXPerFrame, offsetYPerFrame
    ).toGC());
}

void setFontNull(typeof(null))
{
    import hip.global.gamedef;
    textBatch.setFont(cast(IHipFont)HipDefaultAssets.font);
}
void setFont(IHipFont font)
{
    if(font is null)
        setFontNull(null);
    else
        textBatch.setFont(font);
}
void setFontDeferred(IHipAssetLoadTask task)
{
    if(task is null)
        setFontNull(null);
    else
        textBatch.setFont(task);
}

void drawText(string text, int x, int y, in HipColorf color = HipColorf.white, HipTextAlign alignH = HipTextAlign.LEFT, HipTextAlign alignV = HipTextAlign.CENTER, 
int boundsWidth = -1, int boundsHeight = -1)
{
    manageBatchChange(textBatch);
    textBatch.setColor(color);
    textBatch.draw(text, x, y, alignH, alignV, boundsWidth, boundsHeight);
}

Array2D_GC!IHipTextureRegion cropSpritesheetRowsAndColumns(IHipTexture t, uint rows, uint columns)
{
    uint frameWidth = t.getWidth() / columns;
    uint frameHeight = t.getHeight() / rows;
    return cropSpritesheet(t,frameWidth,frameHeight, t.getWidth, t.getHeight, 0, 0, 0, 0);
}

void finishRender2D()
{
    if(geoBatch) renderGeometries();
    if(spBatch) renderSprites();
    if(textBatch) renderTexts();
    lastBatch = null;
    sharedDepth = 0;
    if(geoBatch) geoBatch.setCurrentDepth(0);
    if(spBatch) spBatch.setCurrentDepth(0);
    if(textBatch) textBatch.setCurrentDepth(0);
}

version(Standalone)
{
    public import exportd;
}