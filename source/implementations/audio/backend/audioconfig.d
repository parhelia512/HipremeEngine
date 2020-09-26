module implementations.audio.backend.audioconfig;
import bindbc.sdl.mixer;
import bindbc.sdl : SDL_AudioFormat;
import bindbc.openal;

struct AudioConfig
{
    int sampleRate;
    ushort format;
    int channels;
    int bufferSize;
    /**
    *   Returns a default audio configuration for 2D
    */
    static AudioConfig musicConfig()
    {
        AudioConfig cfg;
        cfg.sampleRate = 44_100;
        cfg.format = MIX_DEFAULT_FORMAT;
        cfg.channels = 2U;
        cfg.bufferSize = 4096;
        return cfg;
    }
    static AudioConfig lightweightConfig()
    {
        AudioConfig cfg;
        cfg.sampleRate = 22_050;
        cfg.format = MIX_DEFAULT_FORMAT;
        cfg.channels = 1U;
        cfg.bufferSize = 2048;
        return cfg;
    }
    SDL_AudioFormat getFormatAsSDL_AudioFormat()
    {
        if(format == MIX_DEFAULT_FORMAT)
        {
            version(LittleEndian)
            {
                return SDL_AudioFormat.AUDIO_S16LSB;
            }
            else
            {
                return SDL_AudioFormat.AUDIO_S16MSB;
            }
        }
        return SDL_AudioFormat.AUDIO_S16;
    }
    
    ALuint getFormatAsOpenAL()
    {
        if(channels == 1)
        {
            if(format == SDL_AudioFormat.AUDIO_S16 || format == SDL_AudioFormat.AUDIO_S16LSB || format == SDL_AudioFormat.AUDIO_S16MSB)
                return AL_FORMAT_MONO16;
            else
                return AL_FORMAT_MONO8;
        }
        else
        {
            if(format == SDL_AudioFormat.AUDIO_S16 || format == SDL_AudioFormat.AUDIO_S16LSB || format == SDL_AudioFormat.AUDIO_S16MSB)
                return AL_FORMAT_STEREO16;
            else
                return AL_FORMAT_STEREO8;
        }
    }

    
}