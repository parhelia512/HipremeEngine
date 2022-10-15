/*
Copyright: Marcelo S. N. Mancini (Hipreme|MrcSnm), 2018 - 2021
License:   [https://creativecommons.org/licenses/by/4.0/|CC BY-4.0 License].
Authors: Marcelo S. N. Mancini

	Copyright Marcelo S. N. Mancini 2018 - 2021.
Distributed under the CC BY-4.0 License.
   (See accompanying file LICENSE.txt or copy at
	https://creativecommons.org/licenses/by/4.0/
*/
module hip.hipaudio.audiosource;
import bindbc.openal;
import hip.hipaudio.audioclip : HipAudioClip;
import hip.hipaudio.audio;
public import hip.api.audio.audiosource;

import hip.math.vector;
import hip.debugging.gui;

/** 
*   Wraps properties for the AudioPlayer. The closest graphical represetantion
*   to that would be the Material class, but for Audios.
*
*/

@InterfaceImplementation(function(ref void* data)
{
    version(CIMGUI)
    {
        import hip.imgui.fonts.icons;
        import bindbc.cimgui;
        HipAudioSource* src = cast(HipAudioSource*)data;
        igBeginGroup();
        igCheckbox("Playing", &src.isPlaying);
        if(src.isPlaying)
        {
            igIndent(0);
            igText("Sound Name: %s %s", src.buffer.fileName.ptr, Icons_FontAwesome.FILE_AUDIO);
            igUnindent(0);
        }
        igSliderFloat("Pitch", &src.pitch, 0, 4, "%0.4f", 0);
        igSliderFloat("Panning", &src.panning, -1, 1, "%0.3f", 0);
        igSliderFloat("Volume", &src.volume, 0, 1, "%0.3f", 0);
        igSliderFloat("Reference Distance", &src.referenceDistance, 0, 65_000, "%0.3f", 0);
        igSliderFloat("Rolloff Factor", &src.rolloffFactor, 0, 1, "%0.3f", 0);
        igSliderFloat("Max Distance", &src.maxDistance, 0, 65_000, "%0.3f", 0);
        igEndGroup();
        HipAudio.update(*src);
    }

}) public class HipAudioSource : AHipAudioSource
{
    public:
    //Functions
        void attachToPosition(){}
        void attachOnDestroy(){}
        override float getProgress(){return time/length;}
        override void pullStreamData(){}
        void setClip(IHipAudioClip clip){this.clip = clip;}
        override HipAudioBufferWrapper* getFreeBuffer(){return null;}

        final void sendAvailableBuffer(void* buffer)
        {
            (cast(HipAudioClip)clip).setBufferAvailable(buffer);
        }

        override HipAudioSource clean()
        {
            isLooping = false;
            isPlaying = false;
            HipAudio.stop(this);
            length = 0;
            HipAudio.setPitch(this, 1f);
            HipAudio.setPanning(this, 0f);
            HipAudio.setVolume(this, 1f);
            HipAudio.setMaxDistance(this, 0f);
            HipAudio.setRolloffFactor(this, 1f);
            HipAudio.setReferenceDistance(this, 0f);
            position = Vector3.zero();
            id = 0;
            clip = null;
            return this;
        }

        
        //Making 3D concept available for every audio, it can be useful
        // Vector!float position = [0f,0f,0f];
        Vector3 position = [0f,0f,0f];
        uint id;
}
