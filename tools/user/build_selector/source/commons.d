module commons;
public import arsd.terminal;
public import std.array:join, split;
public import std.json;
public import std.path;
public import std.process;
public static import std.file;

enum ConfigFile = "gamebuild.json";
__gshared JSONValue configs;

struct Choice
{
	string name;
	void function(Choice* self, ref Terminal t, ref RealTimeConsoleInput input) onSelected;
	bool opEquals(string choiceName) const
	{
		return name == choiceName;	
	}
}

size_t selectChoiceBase(ref Terminal terminal, ref RealTimeConsoleInput input, Choice[] choices, 
	string selectionTitle, size_t selectedChoice = 0)
{
	bool exit;
	enum ArrowUp = 983078;
	enum ArrowDown = 983080;
	while(!exit)
	{
		terminal.color(Color.DEFAULT, Color.DEFAULT);
		if(selectionTitle.length != 0)
			terminal.writeln(selectionTitle);
		terminal.writeln("Select an option by using W/S or Arrow Up/Down and choose it by pressing Enter.");
		foreach(i, choice; choices)
		{
			if(i == selectedChoice)
			{
				terminal.color(Color.green, Color.DEFAULT);
				terminal.writeln(">> ", choice.name);
			}
			else
			{
				terminal.color(Color.DEFAULT, Color.DEFAULT);
				terminal.writeln(choice.name);
			}
		}
		dchar ch;
		bool inputLoop = true;
		while(inputLoop)
		{
			if(ch == 'w' || ch == 'W' || ch == ArrowUp)
			{
				inputLoop = false;
				if(selectedChoice == 0) selectedChoice = choices.length - 1;
				else selectedChoice--;
			}
			else if(ch == 's' || ch == 'S' || ch == ArrowDown)
			{
				selectedChoice = (selectedChoice+1) % choices.length;
				inputLoop = false;
			}
			else if(ch == '\n')
			{
				inputLoop = false;
				exit = true;
			}
			else
				ch =input.getch;
		}
		terminal.clear();
	}
	return selectedChoice;
}


string getValidPath(ref Terminal t, string pathRequired)
{
	string path;
	while(true)
	{
		path = t.getline(pathRequired);
		if(std.file.exists(path))
			return path;
	}
}

string getFirstExisting(string basePath, scope string[] tests...)
{
	foreach(t; tests)
	{
		auto temp = buildNormalizedPath(basePath, t);
		if(std.file.exists(temp)) return temp;
	}
	return "";
}


string findProgramPath(string program)
{
	import std.algorithm:countUntil;
	import std.process;
	string searcher;
	version(Windows) searcher = "where";
	else version(Posix) searcher = "which";
	else static assert(false, "No searcher program found in this OS.");
	auto shellRes = execute([searcher, program]);
    if(shellRes.output)
		return shellRes.output[0..shellRes.output.countUntil("\n")];
   	return null;
}

void writelnHighlighted(ref Terminal t, scope string[] what...)
{
	t.color(Color.yellow, Color.DEFAULT);
	t.writeln(what.join());
	t.color(Color.DEFAULT, Color.DEFAULT);
}

void writelnSuccess(ref Terminal t, scope string[] what...)
{
	t.color(Color.green, Color.DEFAULT);
	t.writeln(what.join());
	t.color(Color.DEFAULT, Color.DEFAULT);
}

void writelnError(ref Terminal t, scope string[] what...)
{
	t.color(Color.red, Color.DEFAULT);
	t.writeln(what.join());
	t.color(Color.DEFAULT, Color.DEFAULT);
}

bool pollForExecutionPermission(ref Terminal t, ref RealTimeConsoleInput input, string operation)
{
	dchar shouldPermit;
	t.writelnHighlighted(operation);
	t.flush;
	while(true)
	{
		shouldPermit = input.getch;
		if(shouldPermit == 'y' || shouldPermit == 'Y') break;
		else if(shouldPermit == 'n' || shouldPermit == 'N') return false;
	}
	return true;
}

bool extractZipToFolder(string zipPath, string outputDirectory, ref Terminal t)
{
	import std.zip;
	ZipArchive zip = new ZipArchive(std.file.read(zipPath));
	if(!std.file.exists(outputDirectory))
	{
		t.writeln("Creating directory ", outputDirectory);
		t.flush;
		std.file.mkdirRecurse(outputDirectory);
	}
	foreach(fileName, archiveMember; zip.directory)
	{
		string outputFile = buildNormalizedPath(outputDirectory, fileName);
		if(!std.file.exists(outputFile))
		{
			string currentDirName = outputFile;
			///For some reason on linux it thinks that .a files are directories
			if(std.file.attrIsFile(archiveMember.fileAttributes) || currentDirName.extension == ".a")
			{
				t.writeln("Extracting ", fileName);
				t.flush;
				currentDirName = currentDirName.dirName;
				std.file.mkdirRecurse(currentDirName);
				std.file.write(outputFile, zip.expand(archiveMember));
			}
			else
				std.file.mkdirRecurse(currentDirName);
		}
	}
	return true;
}

bool makeFileExecutable(string filePath)
{
	version(Windows) return true;
	version(linux)
	{
		if(!std.file.exists(filePath)) return false;
		import std.conv:octal;
		std.file.setAttributes(filePath, octal!700);
		return true;
	}
}

bool downloadFileIfNotExists(
	string purpose, string link, string outputName,
	ref Terminal t, ref RealTimeConsoleInput input
)
{
	import std.net.curl;
	if(!std.file.exists(outputName))
	{
		if(!pollForExecutionPermission(t, input, purpose~" [Y]es/[N]o"))
			return false;
		download(link, outputName);
		t.writeln("Download succeeded!");
		t.flush;
	}
	return true;
}

void updateConfigFile()
{
	std.file.write(ConfigFile, configs.toJSON());
}

void loadSubmodules(ref Terminal t)
{
	import std.process;
	if(!findProgramPath("git"))
		throw new Error("Git wasn't found. Git is necessary for loading the engine submodules.");
	t.writelnSuccess("Updating Git Submodules");
	t.flush;
	executeShell("git submodule update --init --recursive");
}


void runEngineDScript(ref Terminal t, string script, scope string[] args...)
{
	t.writeln("Executing engine script ", script, " with arguments ", args);
	t.flush;
	auto output = execute(["rdmd", buildNormalizedPath(configs["hipremeEnginePath"].str, "tools", "build", script)] ~ args);
	if(output.status)
	{
		t.writelnError("Script ", script, " failed with: ", output.output);
		t.flush;
		throw new Error("Failed on engine script");
	}
}


void putResourcesIn(ref Terminal t, string where)
{
	runEngineDScript(t, "copyresources.d", buildNormalizedPath(configs["gamePath"].str, "assets"), where);
}


string selectInFolder(string directory, ref Terminal t, ref RealTimeConsoleInput input)
{
	Choice[] choices;
	foreach(std.file.DirEntry e; std.file.dirEntries(directory, std.file.SpanMode.shallow))
		choices~= Choice(e.name, null);
	size_t choice;
	choice = selectChoiceBase(t, input, choices, "Select the NDK which you want to use. Remember that only NDK <= 21 is supported.");

	return choices[choice].name;
}