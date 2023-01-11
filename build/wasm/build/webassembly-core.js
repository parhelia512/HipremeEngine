
// can webassembly's main be async?
// I might be able to make a semaphore out of
// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Atomics/wait

// stores { object: o, refcount: n }
var bridgeObjects = [{}]; // the first one is a null object; ignored
// placeholder to be filled in by the loader
var memory;
var printBlockDebugInfo;
var bridge_malloc;
var exports;

function memdump(address, length) {
	var a = new Uint32Array(memory.buffer, address, length);
	console.log(a);
}

function meminfo() {
	document.getElementById("stdout").innerHTML = "";
	printBlockDebugInfo(0);
}


var dModules = {};
var savedFunctions = {};
const utf8Encoder = new TextEncoder("utf-8");
const utf8Decoder = new TextDecoder();
const WasmUtils = {
	toDString(str)
	{
		const s = utf8Encoder.encode(str);
		const ptr = bridge_malloc(s.byteLength + 4);
		let view = new Uint32Array(memory.buffer, ptr, 1);
		view[0] = s.byteLength;
		let view2 = new Uint8Array(memory.buffer, ptr + 4, s.length);
		view2.set(s);
		return ptr;
	},
	toDArguments(...args)
	{
		//Calculate total length before.
		let allocLength = 4;
		const size_t = 4;
		for(let i = 0; i < args.length; i++)
		{
			switch(typeof(args[i]))
			{
				case "boolean":
				case "number":
					allocLength+= size_t;
					break;
				case "string":
					//Allocates a slice (ptr+length) and the characters.
					allocLength+= utf8Encoder.encode(args[i]).length + size_t;
					break;
				case "object":
					throw new Error("To Be Implemented for arrays.");
				default: throw new Error("Can't send argument "+args[i]+ " to D.");
			}
		}
		const ptr = bridge_malloc(allocLength);
		let view = new DataView(memory.buffer, ptr, allocLength);
		//Always pass count of arguments first
		view.setUint32(0, args.length, true);
		let offset = 4;
		for(let i = 0; i < args.length; i++)
		{
			switch(typeof(args[i]))
			{
				case "boolean":
				case "number":
					view.setUint32(offset, args[i], true);
					offset+= size_t;
					break;
				case "string":
				{
					let strData = utf8Encoder.encode(args[i]);
					view.setUint32(offset, strData.byteLength, true);//Size
					offset+= size_t;
					new Uint8Array(memory.buffer, ptr+offset, strData.byteLength).set(strData);
					offset+= strData.length;
					break;
				}
				case "object":
					throw new Error("To Be Implemented for arrays.");
			}
		}
		console.log(ptr)
		return ptr;
	},
	fromDString(length, ptr)
	{
		return utf8Decoder.decode(new DataView(memory.buffer, ptr, length));
	},
	binToBase64(ptr, length)
	{
		return btoa(String.fromCharCode.apply(null, new Uint8Array(memory.buffer, ptr, length)));
	},
	_objects: [],
    addObject(val){return 0;}, //Overridden in hidden context
    removeObject(val){return 0;}
};

(function()
{
	const _objects = WasmUtils._objects;
    const _freelist = [];
    let _last = 0;
	WasmUtils.addObject = function(val)
    {
        if(val === null || val === undefined) return 0;
        let idx = _freelist.pop() || ++_last;
        _objects[idx] = val;
        return idx;
    };
    WasmUtils.removeObject = function(val)
    {
        _freelist.push(val);
        delete _objects[val];
    };
}());



var importObject = {
	env: 
	{
		acquire: function(returnType, modlen, modptr, javascriptCodeStringLength, javascriptCodeStringPointer, argsLength, argsPtr) 
		{
		var td = new TextDecoder();
		var md = td.decode(new Uint8Array(memory.buffer, modptr, modlen));
		var s = td.decode(new Uint8Array(memory.buffer, javascriptCodeStringPointer, javascriptCodeStringLength));

		var jsArgs = [];
		var argIdx = 0;

		var jsArgsNames = "";

		var a = new Uint32Array(memory.buffer, argsPtr, argsLength * 3);
		var aidx = 0;

		for(var argIdx = 0; argIdx < argsLength; argIdx++) {
			var type = a[aidx];
			aidx++;
			var ptr = a[aidx];
			aidx++;
			var length = a[aidx];
			aidx++;

			if(jsArgsNames.length)
				jsArgsNames += ", ";
			jsArgsNames += "$" + argIdx;

			var value;

			switch(type) {
				case 0:
					// an integer was casted to the pointer
					if(ptr & 0x80000000)
						value = - (~ptr + 1); // signed 2's complement
					else
						value = ptr;
				break;
				case 1:
					// pointer+length is a string
					value = td.decode(new Uint8Array(memory.buffer, ptr, length));
				break;
				case 2:
					// a handle
					value = bridgeObjects[ptr].object;
				break;
				case 3:
					// float passed by ref cuz idk how else to reinterpret cast in js
					value = (new Float32Array(memory.buffer, ptr, 1))[0];
				break;
				case 4:
					// float passed by ref cuz idk how else to reinterpret cast in js
					value = (new Uint8Array(memory.buffer, ptr, length));
				break;
				/*
				case 5:
					// a pointer to a delegate
					let p1 = a[ptr];
					let p2 = a[ptr + 1];
					value = function()
				break;
				*/
			}

			jsArgs.push(value);
		}

		///*
		var func = savedFunctions[s];
		if(!func) {
			func = new Function(jsArgsNames, s);
			savedFunctions[s] = func;
		}
		//*/
		//var func = new Function(jsArgsNames, s);
		var ret = func.apply(dModules[md] ? dModules[md] : (dModules[md] = {}), jsArgs);

		switch(returnType) {
			case 0: // void
				return 0;
			case 1:
				// int
				return ret;
			case 2:
				// float
				var view = new Float32Array(memory.buffer, 0, 1);
				view[0] = ret;
				return 0;
			case 3:
				// boxed object
				var handle = bridgeObjects.length;
				bridgeObjects.push({ refcount: 1, object: ret });
				return handle;
			case 4:
				// ubyte[] into given buffer
			case 5:
				// malloc'd ubyte[]
			case 6:
				// string into given buffer
			case 7:
				// malloc'd string. it puts the length as an int before the string, then returns the pointer.
				var te = new TextEncoder();
				var s = te.encode(ret);
				var ptr = bridge_malloc(s.byteLength + 4);
				var view = new Uint32Array(memory.buffer, ptr, 1);
				view[0] = s.byteLength;
				var view2 = new Uint8Array(memory.buffer, ptr + 4, s.length);
				view2.set(s);
				return ptr;
			case 8:
				// return the function itself, so box it up but do not actually call it
		}
		return -1;
	},

	table: new WebAssembly.Table({initial: 4, element: "anyfunc"}),
	__table_base: 0,
	tableBase: 0,

	retain: function(handle) {
		bridgeObjects[handle].refcount++;
	},
	release: function(handle) {
		bridgeObjects[handle].refcount--;
		if(bridgeObjects[handle].refcount <= 0) {
			//console.log("freeing " + handle);
			bridgeObjects[handle] = null;
			if(handle + 1 == bridgeObjects.length)
				bridgeObjects.pop();
		}
	},
	callDg: function(handleA, handleB, handleC)
	{
		const args = WasmUtils.toDArguments(handleB, handleC);
		exports.__callDFunction(handleA, args);
		exports.__callDFunction(handleA, args);
		exports.__callDFunction(handleA, args);
	},
	abort: function() {
		if(window.druntimeAbortHook !== undefined) druntimeAbortHook();
		throw new Error("DRuntime Aborted Wasm");
	},
	_Unwind_Resume: function() {},

	monotimeNow: function() {
		return performance.now()|0;
	},
	_getFuncAddress(func)
	{
		return func;
	},
	JS_Math_random : Math.random,
	atan2f: Math.atan2,
	tanf: Math.tan,
	log2: Math.log2,
	cosf: Math.cos,
	acosf: Math.acos,
	sinf: Math.sin,
	sqrtf: Math.sqrt,
}};

(function()
{
	const glEnv = initializeWebglContext();
	for (const functionName in glEnv) 
	{
		importObject.env[functionName] = glEnv[functionName];
	}
	const decEnv = initializeDecoders();
	for (const functionName in decEnv)
	{
		importObject.env[functionName] = decEnv[functionName];
	}
}());