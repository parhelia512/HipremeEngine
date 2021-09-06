/*
Copyright: Marcelo S. N. Mancini, 2018 - 2021
License:   [https://opensource.org/licenses/MIT|MIT License].
Authors: Marcelo S. N. Mancini

	Copyright Marcelo S. N. Mancini 2018 - 2021.
Distributed under the MIT Software License.
   (See accompanying file LICENSE.txt or copy at
	https://opensource.org/licenses/MIT)
*/

module graphics.g2d.spritebatch;
import graphics.mesh;
import core.stdc.string:memcpy;
import graphics.orthocamera;
import hiprenderer.renderer;
import math.matrix;
import error.handler;
import hiprenderer.shader;
import graphics.material;
import graphics.g2d.sprite;
import graphics.color;
import math.vector;

/**
*   This is what to expect in each vertex sent to the sprite batch
*/
struct HipSpriteVertex
{
    Vector3 position;
    HipColor color;
    Vector2 tex_uv;

    static enum floatCount = cast(ulong)(HipSpriteVertex.sizeof/float.sizeof);
    static enum quadCount = floatCount*4;
}

private enum spriteVertexSize = cast(uint)(HipSpriteVertex.sizeof/float.sizeof);

class HipSpriteBatch
{
    index_t maxQuads;
    index_t[] indices;
    float[] vertices;
    bool hasBegun;
    Shader shader;
    HipOrthoCamera camera;
    Mesh mesh;
    Material material;

    protected uint quadsCount;

    this(index_t maxQuads = 10_900)
    {
        import std.conv:to;
        ErrorHandler.assertExit(is(index_t == ushort) && index_t.max > maxQuads * 6, "Invalid max quads. Max is "~to!string(index_t.max/6));
        this.maxQuads = maxQuads;
        indices = new index_t[maxQuads*6];
        vertices = new float[maxQuads*spriteVertexSize*4]; //XYZ -> 3, RGBA -> 4, ST -> 2, 3+4+2=9
        vertices[] = 0;

        Shader s = HipRenderer.newShader(HipShaderPresets.SPRITE_BATCH);
        mesh = new Mesh(HipVertexArrayObject.getXYZ_RGBA_ST_VAO(), s);
        mesh.vao.bind();
        mesh.createVertexBuffer(cast(index_t)(maxQuads*spriteVertexSize*4), HipBufferUsage.DYNAMIC);
        mesh.createIndexBuffer(cast(index_t)(maxQuads*6), HipBufferUsage.STATIC);
        mesh.sendAttributes();
        setShader(s);
        

        shader.addVarLayout(new ShaderVariablesLayout("Cbuf1", ShaderTypes.VERTEX, ShaderHint.NONE)
        .append("uModel", Matrix4.identity)
        .append("uView", Matrix4.identity)
        .append("uProj", Matrix4.identity));

        shader.addVarLayout(new ShaderVariablesLayout("Cbuf", ShaderTypes.FRAGMENT, ShaderHint.NONE)
        .append("uBatchColor", cast(float[4])[1,1,1,1])
        );


        shader.useLayout.Cbuf;
        shader.bind();
        shader.sendVars();

        // material = new Material(mesh.shader);
        // material.setFragmentVar("uBatchColor", cast(float[4])[1,0,0,1]);

        camera = new HipOrthoCamera();

        index_t offset = 0;
        for(index_t i = 0; i < maxQuads; i+=6)
        {
            indices[i + 0] = cast(index_t)(0+offset);
            indices[i + 1] = cast(index_t)(1+offset);
            indices[i + 2] = cast(index_t)(2+offset);

            indices[i + 3] = cast(index_t)(2+offset);
            indices[i + 4] = cast(index_t)(3+offset);
            indices[i + 5] = cast(index_t)(0+offset);
            offset+= 4; //Offset calculated for each quad
        }
        mesh.setVertices(vertices);
        mesh.setIndices(indices);
    }

    void setShader(Shader s)
    {
        this.shader = s;
        mesh.setShader(s);
    }

    void begin()
    {
        if(hasBegun)
            return;
        hasBegun = true;
    }

    void addQuad(const float[HipSpriteVertex.quadCount] quad)
    {
        for(int i = 0; i < 9*4; i++)
            vertices[(9*4*quadsCount)+i] = quad[i];
        quadsCount++;
    }
    void draw(HipSprite s)
    {
        const float[HipSpriteVertex.quadCount] v = s.getVertices();
        ErrorHandler.assertExit(s.width != 0 && s.height != 0, "Tried to draw 0 bounds sprite");

        s.texture.texture.bind();
        ///X Y Z, RGBA, UV, 4 vertices

        addQuad(v);
    }

    void draw(TextureRegion reg, int x, int y, int z = 0, HipColor color = HipColor.white)
    {
        const float[HipSpriteVertex.quadCount] v = getTextureRegionVertices(reg,x,y,z,color);
        ErrorHandler.assertExit(reg.regionWidth != 0 && reg.regionHeight != 0, "Tried to draw 0 bounds sprite");
        reg.texture.bind();
        ///X Y Z, RGBA, UV, 4 vertices

        addQuad(v);
    }

    static float[HipSpriteVertex.floatCount * 4] getTextureRegionVertices(TextureRegion reg,
    int x, int y, int z = 0, HipColor color = HipColor.white)
    {
        float[HipSpriteVertex.floatCount*4] ret;
        
        ret[X1] = x;
        ret[Y1] = y;
        ret[Z1] = z;

        ret[X2] = x+reg.regionWidth;
        ret[Y2] = y;
        ret[Z2] = z;
        
        ret[X3] = x+reg.regionWidth;
        ret[Y3] = y+reg.regionHeight;
        ret[Z3] = z;

        ret[X4] = x;
        ret[Y4] = y+reg.regionHeight;
        ret[Z4] = z;

        const float[8] v = reg.getVertices();
        ret[U1] = v[0];
        ret[V1] = v[1];
        ret[U2] = v[2];
        ret[V2] = v[3];
        ret[U3] = v[4];
        ret[V3] = v[5];
        ret[U4] = v[6];
        ret[V4] = v[7];

        ret[R1] = color.r;
        ret[G1] = color.g;
        ret[B1] = color.b;
        ret[A1] = color.a;

        ret[R2] = color.r;
        ret[G2] = color.g;
        ret[B2] = color.b;
        ret[A2] = color.a;

        ret[R3] = color.r;
        ret[G3] = color.g;
        ret[B3] = color.b;
        ret[A3] = color.a;

        ret[R4] = color.r;
        ret[G4] = color.g;
        ret[B4] = color.b;
        ret[A4] = color.a;
        
        return ret;
    }

    void end()
    {
        if(!hasBegun)
            return;
        this.flush();
        hasBegun = false;
    }

    void flush()
    {
        // mesh.shader.bind();
        // mesh.shader.setFragmentVar("uBatchColor", cast(float[4])[1,1,1,1]);
        // material.bind();
        mesh.shader.setVertexVar("Cbuf1.uProj", camera.proj);
        mesh.shader.setVertexVar("Cbuf1.uModel",Matrix4.identity());
        mesh.shader.setVertexVar("Cbuf1.uView", camera.view);
        
        mesh.shader.bind();
        mesh.shader.sendVars();
        HipRenderer.exitOnError();

        mesh.updateVertices(vertices);
        mesh.draw(quadsCount*6);
        quadsCount = 0;
    }
}


enum
{
    X1 = 0,
    Y1,
    Z1,
    R1,
    G1,
    B1,
    A1,
    U1,
    V1,

    X2,
    Y2,
    Z2,
    R2,
    G2,
    B2,
    A2,
    U2,
    V2,

    X3,
    Y3,
    Z3,
    R3,
    G3,
    B3,
    A3,
    U3,
    V3,

    X4,
    Y4,
    Z4,
    R4,
    G4,
    B4,
    A4,
    U4,
    V4
}