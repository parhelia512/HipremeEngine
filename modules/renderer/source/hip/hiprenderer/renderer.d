/*
Copyright: Marcelo S. N. Mancini (Hipreme|MrcSnm), 2018 - 2021
License:   [https://creativecommons.org/licenses/by/4.0/|CC BY-4.0 License].
Authors: Marcelo S. N. Mancini

	Copyright Marcelo S. N. Mancini 2018 - 2021.
Distributed under the CC BY-4.0 License.
   (See accompanying file LICENSE.txt or copy at
	https://creativecommons.org/licenses/by/4.0/
*/
module hip.hiprenderer.renderer;
public import hip.config.renderer;
public import hip.hiprenderer.shader;
public import hip.hiprenderer.vertex;
public import hip.hiprenderer.framebuffer;
public import hip.hiprenderer.viewport;
public import hip.api.renderer.texture;
public import hip.api.renderer.operations;
public import hip.api.graphics.color;
public import hip.api.renderer.core;
public import hip.api.renderer.shadervar;
import hip.windowing.window;
import hip.math.rect;
import hip.error.handler;
import hip.console.log;


private struct HipRendererResources
{
    IHipTexture[] textures;
    Shader[] shaders;
    IHipVertexArrayImpl[]  vertexArrays;
    IHipRendererBuffer[] buffers;
}

class HipRenderer
{
    static struct Statistics 
    {
        ulong drawCalls;
        ulong renderFrames;
    }
    __gshared
    {
        protected Viewport currentViewport;
        protected Viewport mainViewport;
        protected IHipRendererImpl rendererImpl;
        protected HipRendererMode rendererMode;
        protected Statistics stats;
        public  HipWindow window = null;
        public  Shader currentShader;
        package HipRendererType rendererType = HipRendererType.NONE;

        public uint width, height;
        protected HipRendererConfig currentConfig;

        protected HipRendererResources res;
        protected bool depthTestingEnabled;
        protected HipDepthTestingFunction currentDepthTestFunction;

        protected IHipRendererBuffer quadIndexBuffer;
    }

    public static bool initialize (string confData, string confPath)
    {
        import hip.config.opts;
        import hip.data.ini;
        import hip.hiprenderer.initializer;
        HipINI ini = HipINI.parse(confData, confPath);
        HipRendererConfig cfg;
        rendererType = getRendererTypeFromVersion();
        int renderWidth = HIP_DEFAULT_WINDOW_SIZE[0];
        int renderHeight = HIP_DEFAULT_WINDOW_SIZE[1];
        string defaultRenderer = "OpenGL3";
        version(AppleOS) defaultRenderer = "Metal";
        if(!ini.configFound || !ini.noError)
        {
            import hip.util.string;
            if(!ini.configFound)
                logln("No renderer.conf found");
            if(!ini.noError)
            {
                logln("Renderer.conf parsing error");
                rawerror(BigString(ini.errors).toString);
            }
            hiplog("Defaulting renderer to "~defaultRenderer);
        }
        else
        {
            cfg.bufferingCount = ini.tryGet!ubyte("buffering.count", 2);
            cfg.multisamplingLevel = ini.tryGet!ubyte("multisampling.level", 0);
            cfg.fullscreen = ini.tryGet("screen.fullscreen", false);
            cfg.vsync = ini.tryGet("vsync.on", true);
            
            renderWidth = ini.tryGet("screen.width", renderWidth);
            renderHeight = ini.tryGet("screen.height", renderHeight);
            string renderer = ini.tryGet("screen.renderer", "GL3");
            rendererType = rendererFromString(renderer);
        }
        return initialize(getRendererWithFallback(rendererType), &cfg, renderWidth, renderHeight);
    }

    public static Statistics getStatistics(){return stats;}
    version(dll) public static bool initExternal(HipRendererType type, int windowWidth = -1, int windowHeight = -1)
    {
        import hip.hiprenderer.initializer;
        rendererType = type;
        if(windowWidth == -1)
            windowWidth = 1920;
        if(windowHeight == -1)
            windowHeight = 1080;
        return initialize(getRendererWithFallback(type), null, cast(uint)windowWidth, cast(uint)windowHeight, true);
    }

    private static HipWindow createWindow(uint width, uint height)
    {
        HipWindow wnd = new HipWindow(width, height, HipWindowFlags.DEFAULT);
        version(Android){}
        else wnd.start();
        return wnd;
    }

    /**
    *   Populates a buffer with indices forming quads
    *   If the quadsCount is bigger than the existing one, throws since
    *   it probably can be set at compile time and it is easier to control like that
    */
    public static IHipRendererBuffer getQuadIndexBuffer(size_t quadsCount)
    {
        if(!quadIndexBuffer)
        {
            import hip.util.array;
            quadIndexBuffer = createBuffer(quadsCount*index_t.sizeof*6, HipBufferUsage.STATIC, HipRendererBufferType.index);
            index_t[] output = uninitializedArray!(index_t[])(quadsCount*6);
            index_t index = 0;
            for(index_t i = 0; i < quadsCount; i++)
            {
                output[index+0] = cast(index_t)(i*4+0);
                output[index+1] = cast(index_t)(i*4+1);
                output[index+2] = cast(index_t)(i*4+2);

                output[index+3] = cast(index_t)(i*4+2);
                output[index+4] = cast(index_t)(i*4+3);
                output[index+5] = cast(index_t)(i*4+0);
                index+=6;
            }
            quadIndexBuffer.setData(output);
            import core.memory;
            GC.free(output.ptr);
        }

        return quadIndexBuffer;
    }

    public static bool initialize (IHipRendererImpl impl, HipRendererConfig* config, uint width, uint height, bool isExternal = false)
    {
        ErrorHandler.startListeningForErrors("Renderer initialization");
        if(config != null)
            currentConfig = *config;
        currentConfig.logConfiguration();
        rendererImpl = impl;
        window = createWindow(width, height);
        ErrorHandler.assertErrorMessage(window !is null, "Error creating window", "Could not create Window");
        if(isExternal)
        {
            version(dll)
            {
                if(!rendererImpl.initExternal())
                {
                    ErrorHandler.showErrorMessage("Error Initializing Renderer", "Renderer could not initialize externally");
                    return false;
                }
            }
        }
        else
            rendererImpl.init(window);
        window.setVSyncActive(currentConfig.vsync);
        window.setFullscreen(currentConfig.fullscreen);
        window.show();
        foreach(err; window.errors)
            loglnError(err);
        
        setWindowSize(width, height);
        
        //After init
        import hip.config.opts;
        mainViewport = new Viewport(0,0, window.width, window.height);
        setViewport(mainViewport);
        setColor();
        HipRenderer.setRendererMode(HipRendererMode.TRIANGLES);

        return ErrorHandler.stopListeningForErrors();
    }
    public static void setWindowSize(int width, int height) @nogc
    {
        assert(width > 0 && height > 0, "Window width and height must be greater than 0");
        logln("Changing window size to [", width, ", ",  height, "]");
        window.setSize(cast(uint)width, cast(uint)height);
        HipRenderer.width  = width;
        HipRenderer.height = height;
    }
    public static HipRendererType getType(){return rendererType;}

    /**
     * Info is data that can't be changed from the renderer.
     */
    public static HipRendererInfo getInfo()
    {
        return HipRendererInfo(
            getType,
            rendererImpl.getShaderVarMapper
        );
    }

    public static HipRendererConfig getCurrentConfig(){return currentConfig;}
    public static int getMaxSupportedShaderTextures(){return rendererImpl.queryMaxSupportedPixelShaderTextures();}


    public static IHipTexture getTextureImplementation()
    {
        res.textures~= rendererImpl.createTexture();
        return res.textures[$-1];
    }

    public static void setColor(ubyte r = 255, ubyte g = 255, ubyte b = 255, ubyte a = 255)
    {
        rendererImpl.setColor(r,g,b,a);
    }

    public static Viewport getCurrentViewport() @nogc {return currentViewport;}
    public static void setViewport(Viewport v)
    {
        this.currentViewport = v;
        v.updateForWindowSize(width, height);
        rendererImpl.setViewport(v);
    }

    public static void reinitialize()
    {
        version(Android)
        {
            foreach(tex; res.textures)
            {
                // (cast(Hip_GL3_Texture)tex).reload();
            }
            foreach(shader; res.shaders)
            {
                shader.reload();
            }
        }
    }

    public static void setCamera()
    {
        
    }
    /**
    * Fixes the matrix order based on the config and renderer.
    * If the renderer is column and the config is row, it will tranpose
    */
    public static T getMatrix(T)(auto ref T mat)
    {
        if(currentConfig.isMatrixRowMajor && !rendererImpl.isRowMajor())
            return mat.transpose();
        return mat;
    }

    static Shader newShader()
    {
        res.shaders~= new Shader(rendererImpl.createShader());
        return res.shaders[$-1];
    }
    public static Shader newShader(string vertexShaderPath, string fragmentShaderPath)
    {
        Shader ret = newShader();
        ret.loadShadersFromFiles(vertexShaderPath, fragmentShaderPath);
        return ret;
    }

    public static HipFrameBuffer newFrameBuffer(int width, int height, Shader frameBufferShader = null)
    {
        return new HipFrameBuffer(rendererImpl.createFrameBuffer(width, height), width, height, frameBufferShader);
    }
    public static IHipVertexArrayImpl  createVertexArray()
    {
        res.vertexArrays~= rendererImpl.createVertexArray();
        return res.vertexArrays[$-1];
    }
    public static IHipRendererBuffer createBuffer(size_t size, HipBufferUsage usage, HipRendererBufferType type)
    {
        res.buffers~= rendererImpl.createBuffer(size, usage, type);
        return res.buffers[$-1];
    }
    public static void setShader(Shader s)
    {
        currentShader = s;
        s.bind();
    }
    public static bool hasErrorOccurred(out string err, string file = __FILE__, size_t line =__LINE__)
    {
        return rendererImpl.hasErrorOccurred(err, file, line);
    }

    public static void exitOnError(string file = __FILE__, size_t line = __LINE__)
    {
        import hip.config.opts;
        import core.stdc.stdlib:exit;
        string err;
        if(hasErrorOccurred(err, file, line))
        {
            loglnError(err, file,":",line);
            static if(CustomRuntime)
                exit(-1);
            else
                throw new Error(err);
        }
    }

    public static void begin()
    {

        rendererImpl.begin();
    }
    
    public static void setErrorCheckingEnabled(bool enable = true)
    {
        rendererImpl.setErrorCheckingEnabled(enable);
    }

    public static void setRendererMode(HipRendererMode mode)
    {
        rendererMode = mode;
        rendererImpl.setRendererMode(mode);
    }
    public static HipRendererMode getMode(){return rendererMode;}

    public static void drawIndexed(index_t count, uint offset = 0)
    {
        rendererImpl.drawIndexed(count, offset);
        stats.drawCalls++;
    }
    public static void drawIndexed(HipRendererMode mode, index_t count, uint offset = 0)
    {
        HipRendererMode currMode = rendererMode;
        if(mode != currMode) HipRenderer.setRendererMode(mode);
        HipRenderer.drawIndexed(count, offset);
        stats.drawCalls++;
    }
    public static void drawVertices(index_t count, uint offset = 0)
    {
        rendererImpl.drawVertices(count, offset);
    }
    public static void drawVertices(HipRendererMode mode, index_t count, uint offset = 0)
    {
        rendererImpl.setRendererMode(mode);
        HipRenderer.drawVertices(count, offset);
    }

    public static void end()
    {
        rendererImpl.end();
        foreach(sh; res.shaders) sh.onRenderFrameEnd();
        stats.drawCalls=0;
        stats.renderFrames++;
    }
    public static void clear()
    {
        rendererImpl.clear();
        stats.drawCalls++;
    }
    public static void clear(HipColorf color)
    {
        auto rgba = color.unpackRGBA;
        rendererImpl.clear(rgba[0], rgba[1], rgba[2], rgba[3]);
        stats.drawCalls++;
    }
    public static void clear(ubyte r = 255, ubyte g = 255, ubyte b = 255, ubyte a = 255)
    {
        rendererImpl.clear(r,g,b,a);
        stats.drawCalls++;
    }
    static HipDepthTestingFunction getDepthTestingFunction()
    {
        return currentDepthTestFunction;
    }
    static bool isDepthTestingEnabled()
    {
        return depthTestingEnabled;
    }
    static void setDepthTestingEnabled(bool enable)
    {
        rendererImpl.setDepthTestingEnabled(enable);
    }
    static void setDepthTestingFunction(HipDepthTestingFunction fn)
    {
        rendererImpl.setDepthTestingFunction(fn);
        currentDepthTestFunction = fn;
    }

    static void setStencilTestingEnabled(bool bEnable)
    {
        rendererImpl.setStencilTestingEnabled(bEnable);
    }
    static void setStencilTestingMask(uint mask)
    {
        rendererImpl.setStencilTestingMask(mask);
    }
    static void setColorMask(ubyte r, ubyte g, ubyte b, ubyte a)
    {
        rendererImpl.setColorMask(r,g,b,a);
    }
    static void setStencilTestingFunction(HipStencilTestingFunction passFunc, uint reference, uint mask)
    {
        rendererImpl.setStencilTestingFunction(passFunc, reference, mask);
    }
    static void setStencilOperation(HipStencilOperation stencilFail, HipStencilOperation depthFail, HipStencilOperation stencilAndDephPass)
    {
        rendererImpl.setStencilOperation(stencilFail, depthFail, stencilAndDephPass);
    }
    
    public static void dispose()
    {
        rendererImpl.dispose();
        if(window !is null)
            window.exit();
        window = null;
    }
}

void logConfiguration(HipRendererConfig config)
{
    import hip.console.log;
    with(config)
    {
        loglnInfo("Starting HipRenderer with configuration: ",
        "\nMultisamplingLevel: ", multisamplingLevel,
        "\nBufferingCount: ", bufferingCount,
        "\nFullscreen: ", fullscreen,
        "\nVsync: ", vsync? "activated" : "deactivated");
    }
}