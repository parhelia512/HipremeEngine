/*
Copyright: Marcelo S. N. Mancini (Hipreme|MrcSnm), 2018 - 2021
License:   [https://creativecommons.org/licenses/by/4.0/|CC BY-4.0 License].
Authors: Marcelo S. N. Mancini

	Copyright Marcelo S. N. Mancini 2018 - 2021.
Distributed under the CC BY-4.0 License.
   (See accompanying file LICENSE.txt or copy at
	https://creativecommons.org/licenses/by/4.0/
*/
module util.reflection;
int asInt(alias enumMember)()
{
    alias T = typeof(enumMember);
    foreach(i, mem; __traits(allMembers, T))
    {
        if(mem == enumMember.stringof)
            return i;
    }
    ErrorHandler.assertExit(0, "Member "~enumMember.stringof~" from type " ~ T.stringof~ " does not exist");
}


bool isLiteral(alias variable)(string var = variable.stringof)
{
    import std.string : isNumeric;
    import std.algorithm : count;
    return (isNumeric(var) || count(var, "\"") == 2);
}

auto inverseLookup(alias lookupTable)()
{
    alias O = typeof(lookupTable.keys[0]);
    alias I = typeof(lookupTable.values[0]);
    O[I] output;
    static foreach(k, v; lookupTable)
        output[v] = k;
    return output;
}

/** 
*   Generates a function that executes a switch case from the associative array.
*
*   Pass true as the second parameter if reverse is desired.
*/
template aaToSwitch(alias aa, bool reverse = false)
{
    auto aaToSwitch(T)(T value)
    {
        switch(value)
        {
            static foreach(k, v; aa)
                static if(reverse)
                    case v: return k;
                else
                    case k: return v;                
            default:
                return typeof(return).init;
        }
    }
}


ulong enumLength(T)()
if(is(T == enum))
{
    return __traits(allMembers, T).length;
}

T nullCheck(string expression, T, Q)(T defaultValue, Q target)
{
    import std.traits:ReturnType;
    import std.conv:to;
    import std.string:split;

    enum exps = expression.split(".");
    enum firstExp = exps[0]~"."~exps[1];

    mixin("alias ",exps[0]," = target;");
    
    if(target is null)
        return defaultValue;
    
    static if(mixin("isFunction!("~firstExp~")"))
    {
        mixin("ReturnType!("~firstExp~") _v0 = "~firstExp~";");
        if(_v0 is null) return defaultValue;
    }
    else
        mixin("typeof("~firstExp~") _v0 = " ~ firstExp~";");
    
    static foreach(i, e; exps[2..$])
    {
        static if(mixin("isFunction!(_v"~to!string(i)~"."~e~")"))
        {
            mixin("ReturnType!(_v"~to!string(i)~"."~e~") _v"~to!string(i+1) ~"= _v"~to!string(i)~"."~e~";");
        }
        else
        {
            mixin("typeof(_v"~to!string(i)~"."~e~") _v"~to!string(i+1)~"= _v"~to!string(i)~"."~e~";");
        }
        static if(i != exps[2..$].length - 1)
        	mixin("if (_v"~to!string(i+1)~" is null) return defaultValue;");
    }

    mixin("return _v",to!string(exps.length-2),";");
}


///Used in conjunction to ExportDFunctions, you may specify a suffix, if you so, _suffix is added
struct ExportD
{
    string suffix;  
}
template getParams (alias fn) 
{
	static if ( is(typeof(fn) params == __parameters) )
    	alias getParams = params;
}
template getUDAs(alias symbol)
{
    enum getUDAs = __traits(getAttributes, symbol);
}

template hasUDA(alias symbol, alias UDA)
{
    enum helper = ()
    {
        foreach(att; __traits(getAttributes, symbol))
            if(is(typeof(att) == UDA) || is(att == UDA)) return true;
        return false;
    }();
    enum hasUDA = helper;
}

template generateExportName(string className, alias funcSymbol)
{
	//Means that it has a suffix
	static if(is(typeof(getUDAs!funcSymbol[0]) == ExportD))
		enum generateExportName = className~"_"~__traits(identifier, funcSymbol)~"_"~getUDAs!funcSymbol[0].suffix;
	else
		enum generateExportName = className~"_"~__traits(identifier, funcSymbol);
}

template getSymbolsByUDA(alias root, alias UDA)
{
    enum helper = ()
    {
        foreach(mem; __traits(allMembers, root))
        {

        }

    }();
    enum getSymbolsByUDA = helper;
}


string[] exportedFunctions;
mixin template ExportDFunctions(alias mod)
{
    import util.string:join;
	import std.traits:getSymbolsByUDA,
                    ParameterIdentifierTuple,
					ReturnType;
	static foreach(mem; __traits(allMembers, mod))
	{
		static if( (is(mixin(mem) == class) || is(mixin(mem) == struct) ))
		{
			static foreach(syms; getSymbolsByUDA!(mixin(mem), ExportD))
			{
                static if(__traits(compiles, mixin(generateExportName!(mem, syms))))
                    static assert(false, "ExportD '" ~ generateExportName!(mem, syms) ~
                    "' is not unique, use ExportD(\"SomeName\") for overloading with a suffix");
                pragma(msg, "Exported "~(generateExportName!(mem, syms)));
				//Func signature
				mixin("extern(System) export ", ReturnType!syms, " ", generateExportName!(mem, syms), getParams!syms.stringof,
				// Func content
					"{ return "~mem~"."~__traits(identifier, syms)~"(",[ParameterIdentifierTuple!syms].join(","),");}");
			}

            // mixin(q{shared static this(){}})
		}
	}
}
