module implementations.renderer.backend.d3d.renderer;
version(Windows):

pragma(lib, "ole32");
pragma(lib, "user32");
pragma(lib, "d3dcompiler");
pragma(lib, "d3d11");
pragma(lib, "dxgi");
import global.consts;
import implementations.renderer.renderer;
import implementations.renderer.shader;
import implementations.renderer.backend.d3d.shader;
import implementations.renderer.backend.d3d.utils;
import error.handler;

import graphics.texture;
import graphics.g2d.viewport;
import core.stdc.string;
import directx.d3d11;
import core.sys.windows.windows;
import bindbc.sdl;

enum RendererMode
{
    POINT,
    LINE,
    LINE_STRIP,
    TRIANGLE,
    TRIANGLE_STRIP
}

ID3D11Device _hip_d3d_device = null;
ID3D11DeviceContext _hip_d3d_context = null;
IDXGISwapChain _hip_d3d_swapChain = null;
ID3D11RenderTargetView _hip_d3d_mainRenderTarget = null;


private void Hip_D3D11_Dispose()
{
    if(_hip_d3d_swapChain)
    {
        _hip_d3d_swapChain.SetFullscreenState(FALSE, null);
        _hip_d3d_swapChain.Release();
        _hip_d3d_swapChain = null;
    }
    if(_hip_d3d_context)
    {
        _hip_d3d_context.Release();
        _hip_d3d_context = null;
    }
    if(_hip_d3d_device)
    {
        _hip_d3d_device.Release();
        _hip_d3d_device = null;
    }
    if(_hip_d3d_mainRenderTarget)
    {
        _hip_d3d_mainRenderTarget.Release();
        _hip_d3d_mainRenderTarget = null;
    }
}


class Hip_D3D11_Renderer : RendererImpl
{
    public static SDL_Renderer* renderer = null;
    public static SDL_Window* window = null;
    protected static Viewport currentViewport;
    public static Shader currentShader;

    public SDL_Window* createWindow()
    {
        SDL_SetHint(SDL_HINT_RENDER_DRIVER, "direct3d11");
        static if(HIP_DEBUG)
        {
            SDL_SetHint(SDL_HINT_RENDER_DIRECT3D11_DEBUG, "1");
        }
        alias f = SDL_WindowFlags;
        SDL_WindowFlags flags = f.SDL_WINDOW_RESIZABLE | f.SDL_WINDOW_ALLOW_HIGHDPI;
        SDL_Window* window = SDL_CreateWindow("DX Window", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, 1280, 720, flags);

        return window;
    }
    protected void initD3D(HWND hwnd, HipRendererConfig* config)
    {
        DXGI_SWAP_CHAIN_DESC dsc;
        dsc.OutputWindow = hwnd;
        dsc.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
        dsc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
        dsc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL;

        ubyte bufferCount = 2;
        ubyte samplingLevel = 1;
        if(config != null)
            bufferCount = config.bufferingCount;
        if(config != null && config.multisamplingLevel > 0)
            samplingLevel = config.multisamplingLevel;

        dsc.BufferCount = bufferCount;
        dsc.SampleDesc.Count = samplingLevel;
        dsc.SampleDesc.Quality = 0;
        dsc.Windowed = TRUE; //True
        //Let user being able to switch between fullscreen and windowed
        dsc.Flags = DXGI_SWAP_CHAIN_FLAG_ALLOW_MODE_SWITCH;
        
        // dsc.BufferDesc.Width = 0;
        // dsc.BufferDesc.Height = 0;
        // dsc.BufferDesc.RefreshRate.Numerator = 60;
        // dsc.BufferDesc.RefreshRate.Denominator = 1;

        uint createDeviceFlags = 0;
        static if(HIP_DEBUG){
            pragma(msg, "D3D11_CREATE_DEVICE_DEBUG:\n\tComment this flag if you do not have d3d11 debug device installed");

            /**
            * https://docs.microsoft.com/en-us/windows/win32/direct3d11/overviews-direct3d-11-devices-layers#debug-layer
            *
            * For Windows 10, to create a device that supports the debug layer,
            * enable the "Graphics Tools" optional feature. Go to the Settings panel,
            * under System, Apps & features, Manage optional Features,
            * Add a feature, and then look for "Graphics Tools".
            */
            // createDeviceFlags|= D3D11_CREATE_DEVICE_DEBUG;

        }
        const D3D_FEATURE_LEVEL[] levelArray = [D3D_FEATURE_LEVEL_11_0, D3D_FEATURE_LEVEL_10_0];
        D3D_FEATURE_LEVEL featureLevel;

        auto res = D3D11CreateDeviceAndSwapChain(null,
                                                D3D_DRIVER_TYPE_HARDWARE,
                                                null,
                                                createDeviceFlags,
                                                levelArray.ptr,
                                                cast(uint)levelArray.length,
                                                D3D11_SDK_VERSION,
                                                &dsc,
                                                &_hip_d3d_swapChain,
                                                &_hip_d3d_device,
                                                &featureLevel,
                                                &_hip_d3d_context);


        if(ErrorHandler.assertErrorMessage(SUCCEEDED(res), "D3D11: Error creating device and swap chain", Hip_D3D11_GetErrorMessage(res)))
        {
            Hip_D3D11_Dispose();
            return;
        }

        ID3D11Texture2D pBackBuffer;

        res = _hip_d3d_swapChain.GetBuffer(0, &IID_ID3D11Texture2D, cast(void**)&pBackBuffer);
        ErrorHandler.assertErrorMessage(SUCCEEDED(res), "Error creating D3D11Texture2D", Hip_D3D11_GetErrorMessage(res));

        //Use back buffer address to create a render target
        res = _hip_d3d_device.CreateRenderTargetView(pBackBuffer, null, &_hip_d3d_mainRenderTarget);
        ErrorHandler.assertErrorMessage(SUCCEEDED(res), "Error creating render target view", Hip_D3D11_GetErrorMessage(res));
        pBackBuffer.Release();

        _hip_d3d_context.OMSetRenderTargets(1u, &_hip_d3d_mainRenderTarget, null);
    }
    public SDL_Renderer* createRenderer(SDL_Window* window)
    {
        //D3D Cannot create any sdl renderer
        return null;
        // return SDL_CreateRenderer(window, -1, SDL_RendererFlags.SDL_RENDERER_ACCELERATED);
    }

    public bool setWindowMode(HipWindowMode mode)
    {
        final switch(mode) with(HipWindowMode)
        {
            case BORDERLESS_FULLSCREEN:
                break;
            case FULLSCREEN:
                break;
            case WINDOWED:

                break;
        }
        return false;
    }

    public Shader createShader(bool createDefault)
    {
        return new Shader(new Hip_D3D11_ShaderImpl(), createDefault);
    }
    public bool init(SDL_Window* window, SDL_Renderer* renderer)
    {
        this.window = window;
        this.renderer = renderer;
        SDL_SysWMinfo wmInfo;
        SDL_GetWindowWMInfo(window, &wmInfo);

        HipRendererConfig cfg = HipRenderer.getCurrentConfig();
        initD3D(cast(HWND)wmInfo.info.win.window, &cfg);
        // setShader(createShader(true));

        return ErrorHandler.stopListeningForErrors();
    }


    public void setMode(RendererMode mode)
    {
        if(mode == RendererMode.TRIANGLE)
        {
            _hip_d3d_context.IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
        }
    }

    public void setViewport(Viewport v)
    {
        D3D11_VIEWPORT vp;
        memset(&vp, 0, D3D11_VIEWPORT.sizeof);
        vp.Width = v.w;
        vp.Height = v.h;
        vp.TopLeftX = 0;
        vp.TopLeftY = 0;
        // vp.MinDepth = 0;
        // vp.MaxDepth = 1;

        currentViewport = v;
        _hip_d3d_context.RSSetViewports(1u, &vp);
    }
    


    void setColor(ubyte r = 255, ubyte g = 255, ubyte b = 255, ubyte a = 255){}
    void setShader(Shader s)
    {
        currentShader = s;
    }

    void begin()
    {
        // if(HipRenderer.currentShader != currentShader)
        //     HipRenderer.setShader(currentShader);
        _hip_d3d_context.OMSetRenderTargets(1u, &_hip_d3d_mainRenderTarget, null);
    }
    void end()
    {
        _hip_d3d_swapChain.Present(0,0);
    }
    public void drawRect(){}
    public void drawTriangle(int x1, int y1, int x2, int y2, int x3, int y3){}
    public void fillTriangle(int x1, int y1, int x2, int y2, int x3, int y3){}
    public void drawRect(int x, int y, int w, int h){}

    void render(){}
    void clear(){}
    void clear(ubyte r = 255, ubyte g = 255, ubyte b = 255, ubyte a = 255)
    {
        float[4] color = [cast(float)r/255, cast(float)g/255, cast(float)b/255, cast(float)a/255];
        _hip_d3d_context.ClearRenderTargetView(_hip_d3d_mainRenderTarget, color.ptr);
    }
    public void draw(Texture t, int x, int y){}
    public void draw(Texture t, int x, int y, SDL_Rect* rect){}
    public void fillRect(int x, int y, int width, int height){}
    public void drawLine(int x1, int y1, int x2, int y2){}
    public void drawPixel(int x, int y ){}

    public void dispose()
    {
        Hip_D3D11_Dispose();
    }
}