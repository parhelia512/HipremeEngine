/*
Copyright: Marcelo S. N. Mancini, 2018 - 2021
License:   [https://opensource.org/licenses/MIT|MIT License].
Authors: Marcelo S. N. Mancini

	Copyright Marcelo S. N. Mancini 2018 - 2021.
Distributed under the MIT Software License.
   (See accompanying file LICENSE.txt or copy at
	https://opensource.org/licenses/MIT)
*/

module hipaudio.backend.openal.buffer;
import data.audio.audio;
import hipaudio.audio;
import hipaudio.backend.audiosource;
import data.audio.audioconfig;
import hipaudio.backend.openal.player;
import bindbc.openal;

/** 
 * OpenAL Buffer works in the following way:
 * If the buffer is streamed, it won't be owned by any source, so it will have total control
 * over itself. That way, it can be reused by any source.
 *
 * Else, the buffer will be owned by the source for decoding, updating, and pulling data.
 */
public class HipOpenALBuffer : HipAudioBuffer
{
    this(IHipAudioDecoder decoder)
    {
        super(decoder);
        getNextBuffer();
    }
    this(IHipAudioDecoder decoder, uint chunkSize){super(decoder, chunkSize);}
    void loadALBuffer(uint bufferId, void* data, uint dataSize)
    {
        alBufferData(
            bufferId,
            HipOpenALAudioPlayer.config.getFormatAsOpenAL,
            data,
            dataSize,
            HipOpenALAudioPlayer.config.sampleRate
        );
    }

    override public bool load(in void[] data, HipAudioEncoding encoding, HipAudioType type, bool isStreamed = false)
    {
        if(super.load(data, encoding, type, isStreamed))
        {
            loadALBuffer(bufferPool[0],getBuffer(),cast(uint)getBufferSize());
            return true;
        }
        return false;
    }
    
    override public uint loadStreamed(in void[] data, HipAudioEncoding encoding)
    {
        uint ret = super.loadStreamed(data, encoding);
        if(ret != 0)
        {
            loadALBuffer(getNextBuffer(),getBuffer(),cast(uint)getBufferSize());
            hasBuffer = true;
            return true;
        }
        return false;
    }

    uint updateALSourceStream(uint buffer = 0)
    {
        import console.log;
        uint decoded = updateStream();
        import util.time;
        if(buffer == 0)
            buffer = getNextBuffer();
        loadALBuffer(buffer, outBuffer, decoded);
        return buffer;
    }

    ref ALuint getNextBuffer()
    {
        poolCursor++;
        if(poolCursor == bufferPool.length)
        {
            import console.log;
            bufferPool.length++;
            alGenBuffers(1, &bufferPool[$-1]);
        }
        return bufferPool[poolCursor];
    }
    
    override public void unload()
    {
        super.unload();
        if(bufferPool.length > 0)
            alDeleteBuffers(cast(ALsizei)bufferPool.length, bufferPool.ptr);
        hasBuffer = false;
    }

    /**
    * Id for accessing via OpenAL Soft
    */
    public ALuint[] bufferPool;
    int poolCursor = -1;
    bool hasBuffer;


    ///If not present, it won't call the super class .load(string) for some reason
    alias load = HipAudioBuffer.load;
}
