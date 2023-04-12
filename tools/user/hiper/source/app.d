module app;
import projectgen;
import ui;
import std.file;
import std.stdio;
import std.path;
import std.array;

bool hasSpace(string name)
{
	foreach(ch; name)
		if(ch == ' ')
			return true;
	return false;
}

bool isProjectNameValid(string name)
{
	return name != "" && name != "hiper";
}

int onPathSelected(string path)
{
	if(path == "")
	{
		writeln("No folder selected");
		return 1;
	}

	path = absolutePath(path);
	if(path.exists)
	{
		writeln("Can't generate project at path ", path, ". Folder already exists.");
		return 1;
	}
	writeln("Generating project at path ", path);

	string projName = pathSplitter(path).array[$-1];
	generateProject(path, DubProjectInfo("HipremeEngine", projName), TemplateInfo());
	return 0;
}

int popupForProjectName()
{
	string folderName = showSaveFileDialog("Name of your project(Should not contain spaces)", ["HipremeProject"]);
	if(folderName.length == 0)
	{
		writeln("Execution cancelled. No project will be created.");
		return 1;
	}
	else if(folderName.hasSpace)
	{
		showErrorMessage("Save Project Error", "Your project name should not contain spaces");
		return popupForProjectName();
	}
	else if(folderName[$-1] == '\0')
		folderName = folderName[0..$-1];
	return onPathSelected(folderName);
}

int main(string[] args)
{
	import std.process;
	if(!("HIPREME_ENGINE" in environment))
	{
		writeln("Please setup HIPREME_ENGINE environment variable to hiper being able to correctly generate your project");
		return 1;
	}
	if(args.length < 2)
		return popupForProjectName();
	else
		writeln("Getting the path from argument ", args[1]);
	return onPathSelected(args[1]);
}