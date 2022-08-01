/*
Copyright: Marcelo S. N. Mancini (Hipreme|MrcSnm), 2018 - 2021
License:   [https://creativecommons.org/licenses/by/4.0/|CC BY-4.0 License].
Authors: Marcelo S. N. Mancini

	Copyright Marcelo S. N. Mancini 2018 - 2021.
Distributed under the CC BY-4.0 License.
   (See accompanying file LICENSE.txt or copy at
	https://creativecommons.org/licenses/by/4.0/
*/
module hip.util.reflection;
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


import std.meta:Alias;
//For usage on match!
alias Case = Alias;
void match(alias reference, matches...)()
{
    import std.range:iota;
    static foreach(i; iota(0, matches.length, 2))
    {
        static if(i + 1 < matches.length)
        {
            if(reference == matches[i])
            {
                matches[i+1]();
                return;
            }
        }
    }
    static if(matches.length % 2 != 0)
        matches[$-1]();
}



bool isLiteral(alias variable)(string var = variable.stringof)
{
    import hip.util.string : isNumeric;
    return (isNumeric(var) || (var[0] == '"' && var[$-1] == '"'));
}


///Copy pasted from std.traits for not importing too many things
template isFunction(X...)
if (X.length == 1)
{
    static if (is(typeof(&X[0]) U : U*) && is(U == function) ||
               is(typeof(&X[0]) U == delegate))
    {
        // x is a (nested) function symbol.
        enum isFunction = true;
    }
    else static if (is(X[0] T))
    {
        // x is a type.  Take the type of it and examine.
        enum isFunction = is(T == function);
    }
    else
        enum isFunction = false;
}

template getParams (alias fn) 
{
	static if ( is(typeof(fn) params == __parameters) )
    	alias getParams = params;
}
alias Parameters = getParams;
enum hasModule(string modulePath) = (is(typeof((){mixin("import ", modulePath, ";");})));
enum hasType(string TypeName) = __traits(compiles, {mixin(TypeName, " _;");});


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
template isReference(T)
{
    enum isReference = is(T == class) || is(T == interface);
}
template hasMethod(T, string method, Params...)
{
    enum hasMethod = __traits(hasMember, T, method) && is(getParams!(__traits(getMember, T, method)) == Params);
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
    import hip.util.conv:to;
    import hip.util.string:split;

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
struct ExportD{string suffix;}


template generateExportName(string className, alias funcSymbol)
{
	//Means that it has a suffix
	static if(is(typeof(getUDAs!funcSymbol[0]) == ExportD))
		enum generateExportName = className~"_"~__traits(identifier, funcSymbol)~"_"~getUDAs!funcSymbol[0].suffix;
	else
		enum generateExportName = className~"_"~__traits(identifier, funcSymbol);
}



template generateExportFunc(string className, alias funcSymbol)
{
    import hip.util.string:join;
    import std.traits:ReturnType, ParameterIdentifierTuple;
    enum impl = ()
    {
        alias RetType = ReturnType!funcSymbol;
        string ret = "export extern(System) "~RetType.stringof~" "~generateExportName!(className, funcSymbol);
        ret~= getParams!(funcSymbol).stringof~"{";
        enum isRef = isReference!(RetType);

        static if(isRef)
        {
            ret~= q{
                import hip.util.lifetime;
                return cast(}~RetType.stringof~")"~"hipSaveRef(";

                static if(is(RetType == interface))
                    ret~= "cast(Object)";
                
                ret~= className~"."~__traits(identifier, funcSymbol)~"("~
                [ParameterIdentifierTuple!funcSymbol].join(",")~"));}";
        }
        else
        {
            static if(!is(RetType == void))
                ret~= "return ";
            ret~= className~"."~__traits(identifier, funcSymbol)~"("~
                [ParameterIdentifierTuple!funcSymbol].join(",")~");}";
        }

        return ret;
    }();

    enum generateExportFunc = impl;
}


struct Version
{
    template opDispatch(string s)
    {
        mixin(`version(`~s~`)enum opDispatch=true;else enum opDispatch=false;`);
    }
}



/**
*   Iterates through a module and generates `export` function declaration for each
*   @ExportD function found on it.
*/
mixin template ExportDFunctions(alias mod)
{
	import std.traits:getSymbolsByUDA;
	static foreach(mem; __traits(allMembers, mod))
	{
        //Currently only supported on classes and structs
		static if( (is(mixin(mem) == class) || is(mixin(mem) == struct) ))
		{
			static foreach(syms; getSymbolsByUDA!(mixin(mem), ExportD))
			{
                //Assert that the symbol to generate does not exists yet
                static assert(__traits(compiles, mixin(generateExportName!(mem, syms))),
                "ExportD '" ~ generateExportName!(mem, syms) ~
                "' is not unique, use ExportD(\"SomeName\") for overloading with a suffix");

                pragma(msg, "Exported "~(generateExportName!(mem, syms)));
				//Func signature
                //Check if it is a non value type
                mixin(generateExportFunc!(mem, syms));
			}

		}
	}
}


enum GetFunctionDeclareStatement(alias func, string funcName)()
{
    import std.traits:ReturnType;
    import hip.util.string:join;
    return (ReturnType!func).stringof ~ " " ~ funcName ~ (getParams!func).stringof ~ " " ~  [__traits(getFunctionAttributes, func)].join(" ");
}

enum ForwardFunc(alias func, string funcName, string member)()
{
    import hip.util.string;
    import std.traits:ParameterIdentifierTuple, ReturnType;

    return GetFunctionDeclareStatement!(func, funcName) ~
         "{" ~ (!is(ReturnType!func == void) ? "return ": "") ~ member ~ "." ~funcName ~ "(" ~ [ParameterIdentifierTuple!func].join(",") ~");}";
}

template hasOverload(T,string member, OverloadType)
{
    enum impl()
    {
        bool ret = false;
        static foreach(ov; __traits(getVirtualMethods, T, member))
            static if(is(typeof(ov) == OverloadType))
                ret = true;
        return ret;
    }

    enum hasOverload = impl;
}


enum isMethodImplemented(T, string member, FuncType)()
{
    bool ret;
    static foreach(overload; __traits(getVirtualMethods, T, member))
        if(is(typeof(overload) == FuncType) && !__traits(isAbstractFunction, overload))
            ret = true;
    return ret;
}

///Futurely, it should be changed to use `alias member` instead of getting its string.
enum ForwardInterface(string member, I)() if(is(I == interface))
{
    import hip.util.string:replaceAll;

    return q{
        import hip.util.reflection:isMethodImplemented, ForwardFunc;

        static assert(is(typeof($member) : $I),
            "For forwarding the interface, the member $member should be or implement $I"
        );

        static foreach(m; __traits(allMembers, $I)) 
        static foreach(ov; __traits(getVirtualMethods, $I, m))
        {
            //Check for overloads here
            static if(!isMethodImplemented!(typeof(this), m, typeof(ov)))
                mixin(ForwardFunc!(ov, m, $member.stringof));
        }
    }.replaceAll("$I", I.stringof).replaceAll("$member", member);
}

/**
* This mixin is able to generate runtime accessors. That means that by having a string, it is
*possible to modify 
*/
mixin template GenerateRuntimeAccessors()
{
    T* getProperty(T)(string prop)
    {
        alias T_this = typeof(this);

        switch(prop)
        {
            static foreach(member; __traits(allMembers, T_this))
            {
                static if(is(typeof(__traits(getMember, T_this, member)) == T))
                {
                    case member:
                        return &__traits(getMember, T_this, member);
                }
            }
            default:
                return null;
        }
    }

    void setProperty(T)(string propName, T value)
    {
        T* prop = getProperty!T(propName);
        if(prop !is null)
            *prop = value;
    }
}