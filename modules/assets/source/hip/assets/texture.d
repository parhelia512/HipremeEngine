/*
Copyright: Marcelo S. N. Mancini (Hipreme|MrcSnm), 2018 - 2021
License:   [https://creativecommons.org/licenses/by/4.0/|CC BY-4.0 License].
Authors: Marcelo S. N. Mancini

	Copyright Marcelo S. N. Mancini 2018 - 2021.
Distributed under the CC BY-4.0 License.
   (See accompanying file LICENSE.txt or copy at
	https://creativecommons.org/licenses/by/4.0/
*/

/**
*   Asset representation of a texture
*/
module hip.assets.texture;
import hip.asset;
import hip.error.handler;
import hip.hiprenderer.renderer;
import hip.math.rect;
import hip.assets.image;
public import hip.util.data_structures:Array2D;
public import hip.api.renderer.texture;


import renderer = hip.hiprenderer.texture;
import hip.util.reflection;

class HipTexture : HipAsset, IHipTexture
{
    mixin(ForwardInterface!("textureImpl", IHipTexture));
    
    IImage img;
    int width,height;
    public IHipTexture textureImpl;
    private bool successfullyLoaded;
    public bool hasSuccessfullyLoaded(){return successfullyLoaded;}


    public static HipTexture getPixelTexture()
    {
        static HipTexture pixelTexture;
        if(pixelTexture is null)
        {
            pixelTexture = new HipTexture();
            pixelTexture.img = cast(IImage)Image.getPixelImage; //Cast the immutable away, promise it is immutable
            pixelTexture.textureImpl.load(pixelTexture.img);
        }
        return pixelTexture;
    }
    /**
    *   Initializes with the current renderer type
    */
    protected this()
    {
        super("Texture");
        _typeID = assetTypeID!HipTexture;
        textureImpl = HipRenderer.getTextureImplementation();
    }

    /**
    *   Only use this style of initializing HipTexture if you wish to avoid HipAssetManager usage. 
    *   This is not really recommended as instantiating as simply new HipTexture("path.png") won't add to the asset manager cache.
    */
    this(string path)
    {
        this();
        load(path);
    }

    this(IImage image)
    {
        this();
        if(image !is null)
            load(image);
    }

    alias load = IHipTexture.load;

    /**
    *   Returns whether the load was successful
    */
    public bool load(string path)
    {
        import hip.filesystem.hipfs;
        ubyte[] buffer;
        if(!HipFS.read(path, buffer))            
            return false;

        Image loadedImage = new Image(path, buffer);
        return load(loadedImage);
    }

    protected bool loadImpl(in IImage img)
    {
        successfullyLoaded = textureImpl.load(img);
        width = textureImpl.getWidth;
        height = textureImpl.getHeight;
        return successfullyLoaded;
    }
    
    override void onFinishLoading(){}
    override void onDispose(){}
    
    bool isReady(){
        return bool.init; // TODO: implement
    }
    
    int getWidth(){return width;}
    int getHeight(){return height;}
    
}



class HipTextureRegion : HipAsset
{
    IHipTexture texture;
    public float u1, v1, u2, v2;
    protected float[8] vertices;
    int regionWidth, regionHeight;

    bool hasSuccessfullyLoaded(){return texture && texture.hasSuccessfullyLoaded;}

    this(string texturePath, float u1 = 0, float v1 = 0, float u2 = 1, float v2 = 1)
    {
        super("TextureRegion");
        texture = new HipTexture(texturePath);
        setRegion(u1,v1,u2,v2);
    }

    this(IHipTexture texture, float u1 = 0, float v1 = 0, float u2 = 1, float v2 = 1)
    {
        super("TextureRegion");
        this.texture = texture;
        setRegion(u1,v1,u2,v2);
    }
    this(IHipTexture texture, uint u1, uint v1, uint u2, uint v2)
    {
        super("TextureRegion");
        this.texture = texture;
        setRegion(texture.getWidth, texture.getHeight, u1,  v1, u2, v2);
    }

    ///By passing the width and height values, you'll be able to crop useless frames
    public static Array2D!HipTextureRegion spritesheet(
        IHipTexture t,
        uint frameWidth, uint frameHeight,
        uint width, uint height,
        uint offsetX, uint offsetY,
        uint offsetXPerFrame, uint offsetYPerFrame)
    {
        uint lengthW = width/(frameWidth+offsetXPerFrame);
        uint lengthH = height/(frameHeight+offsetYPerFrame);

        Array2D!HipTextureRegion ret = Array2D!HipTextureRegion(lengthH, lengthW);

        for(int i = 0, fh = 0; fh < height; i++, fh+= frameHeight+offsetXPerFrame)
            for(int j = 0, fw = 0; fw < width; j++, fw+= frameWidth+offsetYPerFrame)
                ret[i,j] = new HipTextureRegion(t, offsetX+fw , offsetY+fh, offsetX+fw+frameWidth, offsetY+fh+frameHeight);

        return ret;
    }
    ///Default spritesheet method that makes a spritesheet from the entire texture
    static Array2D!HipTextureRegion spritesheet(IHipTexture t, uint frameWidth, uint frameHeight)
    {
        return spritesheet(t,frameWidth,frameHeight, t.getWidth, t.getHeight, 0, 0, 0, 0);
    }

     /**
    *   Defines a region for the texture in the following order:
    *   Top-left
    *   Top-Right
    *   Bot-Right
    *   Bot-Left
    */
    public void setRegion(float u1, float v1, float u2, float v2)
    {
        this.u1 = u1;
        this.u2 = u2;
        this.v1 = v1;
        this.v2 = v2;
        regionWidth =  cast(uint)((u2 - u1) * texture.getWidth);
        regionHeight = cast(uint)((v2 - v1) * texture.getHeight);

        //Top left
        vertices[0] = u1;
        vertices[1] = v1;

        //Top right
        vertices[2] = u2;
        vertices[3] = v1;
        
        //Bot right
        vertices[4] = u2;
        vertices[5] = v2;

        //Bot left
        vertices[6] = u1;
        vertices[7] = v2;
    }

    /**
    *   The uint variant from the setRegion receives arguments in a non normalized way to setup
    *   the UV coordinates.
    *   It is better if you wish to just pass where it start and ends.
    *   The region is divided by the width and height
    *   
    */
    void setRegion(uint width, uint height, uint u1, uint v1, uint u2, uint v2)
    {
        float fu1 = u1/cast(float)width;
        float fu2 = u2/cast(float)width;
        float fv1 = v1/cast(float)height;
        float fv2 = v2/cast(float)height;
        setRegion(fu1, fv1, fu2, fv2);
    }

    /**
    *   The UV coordinates passed are divided by the current texture width and height
    */
    void setRegion(uint u1, uint v1, uint u2, uint v2)
    {
        if(texture)
            setRegion(texture.getWidth, texture.getHeight, u1, v1, u2, v2);
    }


    public ref float[8] getVertices(){return vertices;}
    
    override void onFinishLoading(){}
    
    override void onDispose(){}
    
    bool load()
    {
        return bool.init; // TODO: implement
    }
    
    bool isReady()
    {
        return bool.init; // TODO: implement
    }
    
}