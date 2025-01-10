/*
Copyright: Marcelo S. N. Mancini (Hipreme|MrcSnm), 2018 - 2021
License:   [https://creativecommons.org/licenses/by/4.0/|CC BY-4.0 License].
Authors: Marcelo S. N. Mancini

	Copyright Marcelo S. N. Mancini 2018 - 2021.
Distributed under the CC BY-4.0 License.
   (See accompanying file LICENSE.txt or copy at
	https://creativecommons.org/licenses/by/4.0/
*/
module hip.graphics.g2d.spritebatch;
import hip.graphics.mesh;
import hip.graphics.orthocamera;
import hip.hiprenderer.renderer;
import hip.assets.texture;
import hip.hiprenderer.framebuffer;
import hip.error.handler;
import hip.hiprenderer.shader;
public import hip.api.graphics.batch;
public import hip.api.graphics.color;
public import hip.math.vector;
public import hip.math.matrix;

/**
*   This is what to expect in each vertex sent to the sprite batch
*/
@HipShaderInputLayout struct HipSpriteVertex
{
    Vector3 vPosition = Vector3.zero;
    HipColor vColor = HipColor.white;
    Vector2 vTexST = Vector2.zero;
    float vTexID = 0;

    static enum floatCount = cast(size_t)(HipSpriteVertex.sizeof/float.sizeof);
    static enum quadCount = floatCount*4;
    // static assert(HipSpriteVertex.floatCount == 10,  "SpriteVertex should contain 9 floats and 1 int");
}

@HipShaderVertexUniform("Cbuf1")
struct HipSpriteVertexUniform
{
    Matrix4 uModel = Matrix4.identity;
    Matrix4 uView = Matrix4.identity;
    Matrix4 uProj = Matrix4.identity;
}

@HipShaderFragmentUniform("Cbuf")
struct HipSpriteFragmentUniform
{
    float[4] uBatchColor = [1,1,1,1];
    
    @(ShaderHint.Blackbox)
    IHipTexture[] uTex;
}

/**
*   The spritebatch contains 2 shaders.
*   One shader is entirely internal, which you don't have any control, this is for actually being able
*   to draw stuff on the screen.
*
*   The another one is a post processing shader, which the spritebatch doesn't uses by default. If 
*   setPostProcessingShader()
*/
class HipSpriteBatch : IHipBatch
{
    index_t maxQuads;
    index_t[] indices;
    HipSpriteVertex[] vertices;

    protected bool hasInitTextureSlots;
    Shader spriteBatchShader;

    ///Post Processing Shader
    protected Shader ppShader;
    protected HipFrameBuffer fb;
    protected HipTextureRegion fbTexRegion;
    protected float managedDepth = 0;

    HipOrthoCamera camera;
    Mesh mesh;

    protected IHipTexture[] currentTextures;
    int usingTexturesCount;

    uint lastDrawQuadsCount = 0;
    uint quadsCount;


    this(HipOrthoCamera camera = null, index_t maxQuads = 10_900)
    {
        import hip.hiprenderer.initializer;
        import hip.util.conv:to;
        ErrorHandler.assertLazyExit(index_t.max > maxQuads * 6, "Invalid max quads. Max is "~to!string(index_t.max/6));
        this.maxQuads = maxQuads;
        indices = new index_t[maxQuads*6];
        vertices = new HipSpriteVertex[maxQuads]; //XYZ -> 3, RGBA -> 4, ST -> 2, TexID 3+4+2+1=10
        vertices[] = HipSpriteVertex.init;
        currentTextures = new IHipTexture[](HipRenderer.getMaxSupportedShaderTextures());
        usingTexturesCount = 0;

        this.spriteBatchShader = newShader(HipShaderPresets.SPRITE_BATCH);
        spriteBatchShader.addVarLayout(ShaderVariablesLayout.from!(HipSpriteVertexUniform)(HipRenderer.getInfo));
        spriteBatchShader.addVarLayout(ShaderVariablesLayout.from!(HipSpriteFragmentUniform)(HipRenderer.getInfo));
        spriteBatchShader.setBlending(HipBlendFunction.SRC_ALPHA, HipBlendFunction.ONE_MINUS_SRC_ALPHA, HipBlendEquation.ADD);

        mesh = new Mesh(HipVertexArrayObject.getVAO!HipSpriteVertex, spriteBatchShader);
        mesh.vao.bind();
        mesh.createVertexBuffer(cast(index_t)(maxQuads*HipSpriteVertex.quadCount), HipBufferUsage.DYNAMIC);
        mesh.createIndexBuffer(cast(index_t)(maxQuads*6), HipBufferUsage.STATIC);

        

        spriteBatchShader.useLayout.Cbuf;
        // spriteBatchShader.bind();
        // spriteBatchShader.sendVars();

        mesh.sendAttributes();
        

        spriteBatchShader.useLayout.Cbuf;
        spriteBatchShader.bind();
        spriteBatchShader.sendVars();

        if(camera is null)
            camera = new HipOrthoCamera();
        this.camera = camera;
        HipVertexArrayObject.putQuadBatchIndices(indices, maxQuads);
        mesh.setVertices(vertices);
        mesh.setIndices(indices);
        setTexture(HipTexture.getPixelTexture());

        // import hip.console.log;
        // logln(spriteBatchShader.layouts["Cbuf"].);
    }
    void setCurrentDepth(float depth){managedDepth = depth;}

    void setShader(Shader s)
    {
        if(fb is null)
        {
            Viewport v = HipRenderer.getCurrentViewport;
            fb = HipRenderer.newFrameBuffer(cast(int)v.width, cast(int)v.height);
            // fbTexRegion = new HipTextureRegion(fb.getTexture());
        }
        this.ppShader = s;
    }

    /**
    *   Sets the texture slot/index for the current quad and points it to the next quad
    */
    void addQuad(void[] quad, int slot)
    {
        if(quadsCount+1 > maxQuads)
            flush();

        size_t start = quadsCount*4;
        version(none) //D way to do it, but it is also slower
        {
            size_t end = start + HipSpriteVertex.quadCount;
            vertices[start..end] = quad;
            vertices[start+ T1] = slot;
            vertices[start+ T2] = slot;
            vertices[start+ T3] = slot;
            vertices[start+ T4] = slot;
        }
        else
        {
            import core.stdc.string;
            HipSpriteVertex* v = cast(HipSpriteVertex*)vertices.ptr + start;
            memcpy(v, quad.ptr, HipSpriteVertex.sizeof * 4);
            v[0].vTexID = slot;
            v[1].vTexID = slot;
            v[2].vTexID = slot;
            v[3].vTexID = slot;
        }
        
        quadsCount++;
    }

    void addQuads(void[] quadsVertices, int slot)
    {
        import hip.util.array:swapAt;
        assert(quadsVertices.length % (HipSpriteVertex.sizeof*4) == 0, "Count must be divisible by HipSpriteVertex.sizeof*4");
        HipSpriteVertex[] v = cast(HipSpriteVertex[])quadsVertices;
        uint countOfQuads = cast(uint)(v.length / 4);


        while(countOfQuads > 0)
        {
            size_t remainingQuads = this.maxQuads - this.quadsCount;
            if(remainingQuads == 0)
            {
                flush();
                this.usingTexturesCount = 1;
                swapAt(this.currentTextures, 0, slot);//Guarantee the target slot is being used
                remainingQuads = this.maxQuads;
            }
            size_t quadsToDraw = (countOfQuads < remainingQuads) ? countOfQuads : remainingQuads;


            size_t start = quadsCount*4;
            size_t end = start + quadsToDraw*4;

            vertices[start..end] = v;
            for(int i = 0; i < quadsToDraw; i++)
                setTID(vertices[start+i..$], slot);

            v = v[quadsToDraw*4..$];

            if(quadsToDraw + remainingQuads == maxQuads)
            {
                flush();
                this.usingTexturesCount = 1;
                swapAt(this.currentTextures, 0, slot);//Guarantee the target slot is being used
            }
            else
                this.quadsCount+= quadsToDraw;
            countOfQuads-= quadsToDraw;
        }
    }
    
    private int getNextTextureID(IHipTexture t)
    {
        for(int i = 0; i < usingTexturesCount; i++)
            if(currentTextures[i] is t)
                return i;
        if(usingTexturesCount < currentTextures.length)
        {
            currentTextures[usingTexturesCount] = t;
            return usingTexturesCount++;            
        }
        return -1;
    }
    /**
    *   Sets the current texture in use on the sprite batch and returns its slot.
    */
    protected int setTexture (IHipTexture texture)
    {
        int slot = getNextTextureID(texture);
        if(slot == -1)
        {
            flush();
            slot = getNextTextureID(texture);
        }
        return slot;
    }
    protected int setTexture(IHipTextureRegion reg){return setTexture(reg.getTexture());}

    protected static bool isZeroAlpha(void[] vertices)
    {
        HipSpriteVertex[] v = cast(HipSpriteVertex[])vertices;
        return v[0].vColor.a == 0 && v[1].vColor.a == 0 && v[2].vColor.a == 0 && v[3].vColor.a == 0;
    }

    void draw(IHipTexture t, ubyte[] vertices)
    {
        if(isZeroAlpha(vertices)) return;
        ErrorHandler.assertExit(t.getWidth != 0 && t.getHeight != 0, "Tried to draw 0 bounds sprite");
        int slot = setTexture(t);
        ErrorHandler.assertExit(slot != -1, "HipTexture slot can't be -1 on draw phase");

        if((cast(HipSpriteVertex[])vertices).length == 4)
        {
            addQuad(vertices, slot);
        }
        else
            addQuads(vertices, slot);
    }

    void draw(IHipTexture texture, int x, int y, int z = 0, in HipColor color = HipColor.white, float scaleX = 1, float scaleY = 1, float rotation = 0)
    {
        import hip.global.gamedef;
        if(color.a == 0) return;
        if(quadsCount+1 > maxQuads)
            flush();
        if(texture is null)
            texture = cast()getDefaultTexture();
        ErrorHandler.assertExit(texture.getWidth() != 0 && texture.getHeight() != 0, "Tried to draw 0 bounds texture");
        int slot = setTexture(texture);
        ErrorHandler.assertExit(slot != -1, "HipTexture slot can't be -1 on draw phase");

        size_t startVertex = quadsCount *4;
        size_t endVertex = startVertex + 4;

        getTextureVertices(vertices[startVertex..endVertex], slot, texture,x,y,managedDepth,color, scaleX, scaleY, rotation);
        quadsCount++;
    }


    void draw(IHipTextureRegion reg, int x, int y, int z = 0, in HipColor color = HipColor.white, float scaleX = 1, float scaleY = 1, float rotation = 0)
    {
        if(color.a == 0) return;
        if(quadsCount+1 > maxQuads)
            flush();
        ErrorHandler.assertExit(reg.getWidth() != 0 && reg.getHeight() != 0, "Tried to draw 0 bounds region");
        int slot = setTexture(reg);
        ErrorHandler.assertExit(slot != -1, "HipTexture slot can't be -1 on draw phase");
        size_t startVertex = quadsCount*4;
        size_t endVertex = startVertex + 4;

        getTextureRegionVertices(vertices[startVertex..endVertex], slot, reg,x,y,managedDepth,color, scaleX, scaleY, rotation);
        quadsCount++;
    }

    private static void setColor(HipSpriteVertex[] ret, in HipColor color)
    {
        ret[0].vColor = color;
        ret[1].vColor = color;
        ret[2].vColor = color;
        ret[3].vColor = color;
    }

    private static void setZ(HipSpriteVertex[] vertices, float z)
    {
        vertices[0].vPosition.z = z;
        vertices[1].vPosition.z = z;
        vertices[2].vPosition.z = z;
        vertices[3].vPosition.z = z;
    }
    private static void setUV(HipSpriteVertex[] vertices, const scope ref float[8] uv)
    {
        vertices[0].vTexST = Vector2(uv[0], uv[1]);
        vertices[1].vTexST = Vector2(uv[2], uv[3]);
        vertices[2].vTexST = Vector2(uv[4], uv[5]);
        vertices[3].vTexST = Vector2(uv[6], uv[7]);
    }
    private static void setTID(HipSpriteVertex[] vertices, int tid)
    {
        vertices[0].vTexID = tid;
        vertices[1].vTexID = tid;
        vertices[2].vTexID = tid;
        vertices[3].vTexID = tid;
    }
    private static void setBounds(HipSpriteVertex[] vertices, float x, float y, float width, float height, float scaleX = 1, float scaleY = 1)
    {
        width*= scaleX;
        height*= scaleY;
        vertices[0].vPosition.xy = Vector2(x, y);
        vertices[1].vPosition.xy = Vector2(x+width, y);
        vertices[2].vPosition.xy = Vector2(x+width, y+height);
        vertices[3].vPosition.xy = Vector2(x, y+height);
    }

    private static void setBoundsFromRotation(HipSpriteVertex[] vertices, float x, float y, float width, float height, float rotation, float scaleX = 1, float scaleY = 1)
    {
        import hip.math.utils:cos,sin;
        width*= scaleX;
        height*= scaleY;
        float centerX = -width/2;
        float centerY = -height/2;
        float x2 = x + width;
        float y2 = y + height;
        float c = cos(rotation);
        float s = sin(rotation);

        vertices[0].vPosition.xy = Vector2(c*centerX - s*centerY + x, c*centerY + s*centerX + y);
        vertices[1].vPosition.xy = Vector2(c*x2 - s*centerY + x, c*centerY + s*x2 + y);
        vertices[2].vPosition.xy = Vector2(c*x2 - s*y2 + x, c*y2 + s*x2 + y);
        vertices[3].vPosition.xy = Vector2(c*centerX - s*y2 + x, c*y2 + s*centerX + y);
    }


    static void getTextureVertices(HipSpriteVertex[] output, int slot, IHipTexture texture,
    int x, int y, float z = 0, in HipColor color = HipColor.white, float scaleX = 1, float scaleY = 1, float rotation = 0)
    {
        int width = texture.getWidth();
        int height = texture.getHeight();

        const float[8] v = HipTextureRegion.defaultVertices;
        setUV(output, v);
        setZ(output, z);
        setTID(output, slot);
        setColor(output, color);
        if(rotation == 0)
            setBounds(output, x, y, width, height, scaleX, scaleY);
        else
            setBoundsFromRotation(output, x, y, width, height, rotation, scaleX, scaleY);
    }

    static void getTextureRegionVertices(HipSpriteVertex[] output, int slot, IHipTextureRegion reg,
    int x, int y, float z = 0, in HipColor color = HipColor.white, float scaleX = 1, float scaleY = 1, float rotation = 0)
    {
        int width = reg.getWidth();
        int height = reg.getHeight();
        setZ(output, z);
        setColor(output, color);
        setTID(output, slot);
        setUV(output, reg.getVertices());
        if(rotation == 0)
            setBounds(output, x, y, width, height, scaleX, scaleY);
        else
            setBoundsFromRotation(output, x, y, width, height, rotation, scaleX, scaleY);
    }

    

    void draw()
    {

        if(quadsCount - lastDrawQuadsCount != 0)
        {
            for(int i = usingTexturesCount; i < currentTextures.length; i++)
                currentTextures[i] = currentTextures[0];
            mesh.bind();

            mesh.shader.setVertexVar("Cbuf1.uProj", camera.proj, false);
            mesh.shader.setVertexVar("Cbuf1.uModel",Matrix4.identity(), false);
            mesh.shader.setVertexVar("Cbuf1.uView", camera.view, false);
            mesh.shader.setFragmentVar("Cbuf.uTex", currentTextures);
            mesh.shader.bindArrayOfTextures(currentTextures, "uTex");
            mesh.shader.sendVars();

            size_t start = lastDrawQuadsCount*4;
            size_t end = quadsCount*4;
            mesh.updateVertices(cast(void[])vertices[start..end],cast(int)start);
            mesh.draw((quadsCount-lastDrawQuadsCount)*6, HipRendererMode.TRIANGLES, lastDrawQuadsCount*6);

            ///Some operations may require texture unbinding(D3D11 Framebuffer)
            foreach(i; 0..usingTexturesCount)
                currentTextures[i].unbind(i);
            mesh.unbind();
        }
        lastDrawQuadsCount = quadsCount;
    }

    void flush()
    {
        if(ppShader !is null)
            fb.bind();
        draw();
        lastDrawQuadsCount = quadsCount = usingTexturesCount = 0;
        if(ppShader !is null)
        {
            fb.unbind();
            draw(fbTexRegion, 0,0 );
            draw();
        }
        lastDrawQuadsCount = quadsCount = usingTexturesCount = 0;
    }
}