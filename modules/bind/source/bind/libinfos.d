/*
Copyright: Marcelo S. N. Mancini (Hipreme|MrcSnm), 2018 - 2021
License:   [https://creativecommons.org/licenses/by/4.0/|CC BY-4.0 License].
Authors: Marcelo S. N. Mancini

	Copyright Marcelo S. N. Mancini 2018 - 2021.
Distributed under the CC BY-4.0 License.
   (See accompanying file LICENSE.txt or copy at
	https://creativecommons.org/licenses/by/4.0/
*/
module bind.libinfos;
import bindbc.openal;
import bindbc.opengl;
import console.log;
import core.stdc.string:strlen;
import std.string:fromStringz;

void list_audio_devices(const ALCchar *devices)
{
	const(char)* device = devices;
	const(char)* next = devices + 1;
	size_t len = 0;

	rawlog("Devices list:\n");
	rawlog("----------\n");
	while (device && *device != '\0' && next && *next != '\0') 
	{
		rawlog!"%s\n"(device.fromStringz);
		len = strlen(device);
		device += (len + 1);
		next += (len + 2);
	}
	rawlog("----------\n");
}

void show_sdl_sound_info()
{
    import sdl_sound;
    string toPrint = "SDL2_Sound Available Decoders:\n";
    Sound_DecoderInfo** info = cast(Sound_DecoderInfo**)Sound_AvailableDecoders();
    while(*info != null)
    {
        toPrint~="\n\t"~fromStringz((*info).description);
        toPrint~="\n\tURL:"~fromStringz((*info).url);
        toPrint~="\n\tExtensions: ";
        for(int i = 0; (*info).extensions[i] != null; i++)
        {
            toPrint~= fromStringz((*info).extensions[i]) ~" ";
        }
        toPrint~="\n";
        info++;
    }
    rawlog(toPrint);
}

void show_opengl_info()
{
	version(Android){}
	else{
		if(!isOpenGLLoaded())
		{
			rawlog("OpenGL is not loaded for being able to show info!");
			return;
		}
	}
	rawlog!`OpenGL Infos:
    Vendor:   %s
    Renderer: %s
    Version:  %s`(fromStringz(glGetString(GL_VENDOR)),
    fromStringz(glGetString(GL_RENDERER)),
    fromStringz(glGetString(GL_VERSION)));
}


/** Current OpenSL ES Version*/
immutable SLESVersion = "1.0.1";

/**
* Is feature compatible with...
*/
struct SLESCompatibility
{
    ///Feature compatible with AudioPlayer
    immutable bool AudioPlayer;
    ///Feature compatible with AudioRecorder
    immutable bool AudioRecorder;
    ///Feature compatible with Engine
    immutable bool Engine;
    ///Feature compatible with OutputMix
    immutable bool OutputMix;
}

/**
*   Documentation for permissions needed on android side when using SLES
*/
enum SLESAndroidRequiredPermissions
{
    ///When using any kind of output mix effect
    MODIFY_AUDIO_SETTINGS = `<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>`,
    ///When messing with AudioRecorder
    RECORD_AUDIO = `<uses-permission android:name="android.permission.RECORD_AUDIO"/>`
}

/**
*   Immutable table on how is compatibility at Android, keeping that only as a reference.
*/
enum Android_NDK_Compatibility : SLESCompatibility
{
    //                                            Player  Rec   Engine Output
    BassBoost                  = SLESCompatibility(true, false, false, true),
    BufferQueue                = SLESCompatibility(true, false, false, false),
    BufferQueueDataLocator     = SLESCompatibility(true, false, false, false), //Source
    DynamicInterfaceManagement = SLESCompatibility(true, true, true, true),
    EffectSend                 = SLESCompatibility(true, false, false, false),
    Engine                     = SLESCompatibility(false, false, true, false),
    EnvironmentalReverb        = SLESCompatibility(false, false, false, true),
    Equalize                   = SLESCompatibility(true, false, false, true),
    IODeviceDataLocator        = SLESCompatibility(false, true, false, false),
    MetadataExtraction         = SLESCompatibility(true, false, false, false),
    MuteSolo                   = SLESCompatibility(true, false, false, false),
    OObject                    = SLESCompatibility(true, true, true, true),
    OutputMixLocator           = SLESCompatibility(true, false, false, false), //Sink
    Play                       = SLESCompatibility(true, false, false, false),
    PlaybackRate               = SLESCompatibility(true, false, false, false),
    PrefetchStatus             = SLESCompatibility(true, false, false, false),
    PresetReverb               = SLESCompatibility(false, false, false, true),
    Record                     = SLESCompatibility(false, true, false, false),
    Seek                       = SLESCompatibility(true, false, false, false),
    URIDataLocator             = SLESCompatibility(true, false, false, false), //Source
    Virtualizer                = SLESCompatibility(true, false, false, true),
    Volume                     = SLESCompatibility(true, false, false, false)
    //                                            Player  Rec   Engine Output
}
