module features.android_sdk;

import feature;
import commons;
enum TargetAndroidSDK = 31;

private string getAndroidSDKPackagesToinstall(string sdkMajorVer)
{
	import std.conv:to;
    string packages = `"build-tools;`~(sdkMajorVer)~`.0.0" `~ 
		`"extras;google;webdriver" ` ~
		`"platform-tools" ` ~
		`"platforms;android-`~to!string(sdkMajorVer)~`" `~
		`"sources;android-`~to!string(sdkMajorVer)~`" `;

	version(Windows)
	{
		packages~= `"extras;intel;Hardware_Accelerated_Execution_Manager" `~
					`"extras;google;usb_driver" `;
	}
	return packages;

}

private bool installAndroidSDK(ref Terminal t, ref RealTimeConsoleInput input, TargetVersion ver, Download[] content)
{
    import std.conv:to;
	string outputDirectory = buildNormalizedPath(std.file.getcwd(), "Android", "Sdk");
	string finalOutput = buildNormalizedPath(outputDirectory, "cmdline-tools", "latest");

	if(!std.file.exists(finalOutput))
	{
		if(!extractToFolder(content[0].getOutputPath, outputDirectory, t, input))
			return false;
		std.file.rename(buildNormalizedPath(outputDirectory, "cmdline-tools/"), buildNormalizedPath(outputDirectory, "latest/"));
		std.file.mkdirRecurse(buildNormalizedPath(outputDirectory, "cmdline-tools"));
		std.file.rename(buildNormalizedPath(outputDirectory, "latest"), finalOutput);
	}
    t.writeln("Updating SDK manager.");
	t.flush;
	string sdkManagerPath = buildNormalizedPath(finalOutput, "bin");

	if(!makeFileExecutable(buildNormalizedPath(sdkManagerPath, "sdkmanager")))
	{
		t.writelnError("Failed to set sdkmanager as executable.");
		return false;
	}
    string execSdkManager = "sdkmanager ";
	version(Posix) execSdkManager = "./sdkmanager";

	if(wait(spawnShell("cd "~sdkManagerPath~" && "~execSdkManager~" --install")) != 0)
	{
		t.writelnError("Failed on installing SDK.");
		return false;
	}
    string packagesToInstall = getAndroidSDKPackagesToinstall(ver.major.to!string);

    t.writelnHighlighted("Installing packages: ", packagesToInstall, " \n\t", "You may need to accept some permissions, this process may take a little bit of time.");
    t.flush;

    if(wait(spawnShell("cd "~sdkManagerPath~" && "~execSdkManager ~" " ~packagesToInstall)) != 0)
	{
		t.writelnError("Failed on installing SDK packages.");
		return false;
	}

    string adbPath = buildNormalizedPath(outputDirectory, "platform-tools", "adb");
    if(!makeFileExecutable(adbPath))
	{
		t.writeln("Failed to set ",adbPath," as executable.");
		t.flush;
		return false;
	}

    configs["androidSdkPath"] = outputDirectory;
    updateConfigFile();
	return true;
}

Feature AndroidSDKFeature;
void initialize()
{
    import std.conv:to;
    AndroidSDKFeature = Feature(
        "Android SDK",
        "Required for being able to develop applications for Android",
        ExistenceChecker(["androidSdkPath"]),
        Installation([Download(
            DownloadURL(
                windows:"https://dl.google.com/android/repository/commandlinetools-win-9477386_latest.zip",
                linux: "https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip",
                osx: "https://dl.google.com/android/repository/commandlinetools-mac-9477386_latest.zip"
            )
        )], &installAndroidSDK),
        (ref Terminal t){environment["ANDROID_HOME"] = configs["androidSdkPath"].str;},
        VersionRange.parse(TargetAndroidSDK.to!string)
    );
}
void start(){}