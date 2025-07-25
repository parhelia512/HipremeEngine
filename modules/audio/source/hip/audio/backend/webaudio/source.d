module hip.audio.backend.webaudio.source;

version(WebAssembly):

extern(C) size_t WebAudioSourceCreate();
extern(C) void WebAudioSourceStop(size_t src);
extern(C) void WebAudioSourceSetData(size_t src, size_t buffer);
extern(C) void WebAudioSourceSetPlaying(size_t src, bool playing);
extern(C) void WebAudioSourceSetLooping(size_t src, bool shouldLoop);
extern(C) void WebAudioSourceSetPitch(size_t src, float pitch);
extern(C) void WebAudioSourceSetVolume(size_t src, float volume);
extern(C) void WebAudioSourceSetPlaybackRate(size_t src, float rate);

import hip.audio.backend.webaudio.player;
import hip.audio.backend.webaudio.clip;
import hip.audio.audiosource;
import hip.audio.clip;
import hip.error.handler;


class HipWebAudioSource : HipAudioSource
{
    protected bool isClipDirty = true;
    protected size_t webSrc = 0;

    this(HipWebAudioPlayer player){webSrc = WebAudioSourceCreate();}
    alias clip = HipAudioSource.clip;


    override IHipAudioClip clip(IHipAudioClip newClip)
    {
        if(newClip != clip)
            isClipDirty = true;

        WebAudioSourceSetData(webSrc, getBufferFromAPI(newClip).webaudio);
        super.clip(newClip);
        return newClip;
    }

    alias loop = HipAudioSource.loop;
    override bool loop(bool value)
    {
        bool ret = super.loop(value);
        WebAudioSourceSetLooping(webSrc, value);
        return ret;
    }


    override bool play()
    {
        WebAudioSourceSetPlaying(webSrc, true);
        return true;
    }
    override bool stop()
    {
        WebAudioSourceStop(webSrc);
        return true;
    }
    override bool pause()
    {
        WebAudioSourceSetPlaying(webSrc, false);
        return true;
    }
    override bool play_streamed() => false;


    ~this(){webSrc = 0;}
}
