module view.soundtestscene;
import data.hipfs;
import hipaudio.audio;
// import hipaudio.backend.openal.source;
import data.audio.audio;
import view.scene;

class SoundTestScene : Scene
{
    HipAudioSource src;
    this()
    {
        import console.log;

        // HipAudioClip buf = HipAudio.load("assets/audio/the-sound-of-silence.wav", HipAudioType.SFX);
        // src = HipAudio.getSource(false, buf);
        // HipAudio.play(src);
        
        HipAudioClip buf = HipAudio.loadStreamed("audio/junkyard-a-class.mp3", (ushort.max+1));
        src = HipAudio.getSource(true, buf);
        HipAudio.play_streamed(src);
        src.pullStreamData();
        src.pullStreamData();


    }
    override void update(float dt)
    {
        if(src.getFreeBuffer() != null)
        {
            src.pullStreamData();
        }
    }

    override void render()
    {
    }
}