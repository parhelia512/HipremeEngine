// Written in the D programming language

// NOTE: When working on this module, be sure to run tests with -debug=std_socket
// E.g.: dmd -version=StdUnittest -debug=std_socket -unittest -main -run socket
// This will enable some tests which are too slow or flaky to run as part of CI.

/*
        Copyright (C) 2004-2011 Christopher E. Miller

        socket.d 1.4
        Jan 2011

        Thanks to Benjamin Herr for his assistance.
 */

/**
 * Socket primitives.
 * Example: See $(SAMPLESRC listener.d) and $(SAMPLESRC htmlget.d)
 * License: $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors: Christopher E. Miller, $(HTTP klickverbot.at, David Nadlinger),
 *      $(HTTP thecybershadow.net, Vladimir Panteleev)
 * Source:  $(PHOBOSSRC std/socket.d)
 */
module std.socket;


import core.stdc.stdint,
    core.stdc.stdlib,
    core.stdc.string,
    std.string;

import hip.util.conv:to;
import hip.util.string:isNumber;

import core.stdc.config;
import std.exception;

import std.internal.cstring;

version (iOS)
    version = iOSDerived;
else version (TVOS)
    version = iOSDerived;
else version (WatchOS)
    version = iOSDerived;

@safe:

version(Posix) version = LinuxLike;
version(PSVita) version = LinuxLike;

version(PSVita):

version (Windows)
{
    pragma (lib, "ws2_32.lib");
    pragma (lib, "wsock32.lib");

    import core.sys.windows.winbase, std.windows.syserror;
    public import core.sys.windows.winsock2;
    private alias _ctimeval = core.sys.windows.winsock2.timeval;
    private alias _clinger = core.sys.windows.winsock2.linger;

    enum socket_t : SOCKET { INVALID_SOCKET }
    private const int _SOCKET_ERROR = SOCKET_ERROR;


    private int _lasterr() nothrow @nogc
    {
        return WSAGetLastError();
    }
}
else version (LinuxLike)
{
    version (linux)
    {
        enum : int
        {
            TCP_KEEPIDLE  = 4,
            TCP_KEEPINTVL = 5
        }
        public import core.sys.posix.netinet.in_;
        import core.sys.posix.arpa.inet;
        import core.sys.posix.fcntl;
        import core.sys.posix.netdb;
        import core.sys.posix.netinet.tcp;
        import core.sys.posix.sys.select;
        import core.sys.posix.sys.socket;
        import core.sys.posix.sys.time;
        import core.sys.posix.sys.un : sockaddr_un;
        import core.sys.posix.unistd;
        private alias _ctimeval = core.sys.posix.sys.time.timeval;
        private alias _clinger = core.sys.posix.sys.socket.linger;
        import core.stdc.errno;

    }
    else version(PSVita)
    {
        import std.vita.tcp;
        import std.vita.inet;
        import std.vita.endian;
        import std.vita.errno;
        import std.vita.socket;
        import std.vita.compat;
        import std.vita.netinet_in;
        import std.vita.netdb;

        enum O_NONBLOCK = 0x4000;
        enum F_GETFL = 3;
        enum F_SETFL = 4;
        @nogc @trusted nothrow extern(C) extern int fcntl (int, int, ...);
        @nogc @trusted nothrow extern(C) int     close(int);

        extern(C) int     gethostname(char*, size_t);
        protoent* getprotobyname(T)(T str){return null; }

        extern(C) @nogc @trusted nothrow int select(int, fd_set*, fd_set*, fd_set*, timeval*);
    }



    enum socket_t : int32_t { _init = -1 }
    private const int _SOCKET_ERROR = -1;

    private enum : int
    {
        SD_RECEIVE = SHUT_RD,
        SD_SEND    = SHUT_WR,
        SD_BOTH    = SHUT_RDWR
    }

    private int _lasterr() nothrow @nogc
    {
        return errno;
    }
}
else
{
    static assert(0, "No socket support for this platform yet.");
}


/// Base exception thrown by `std.socket`.
class SocketException: Exception
{
    mixin basicExceptionCtors;
}

version (CRuntime_Glibc) version = GNU_STRERROR;
version (CRuntime_UClibc) version = GNU_STRERROR;

/*
 * Needs to be public so that SocketOSException can be thrown outside of
 * std.socket (since it uses it as a default argument), but it probably doesn't
 * need to actually show up in the docs, since there's not really any public
 * need for it outside of being a default argument.
 */
string formatSocketError(int err) @trusted
{
    version (LinuxLike)
    {
        char[80] buf;
        const(char)* cs;
        version (GNU_STRERROR)
        {
            cs = strerror_r(err, buf.ptr, buf.length);
        }
        else
        {
            auto errs = strerror_r(err, buf.ptr, buf.length);
            if (errs == 0)
                cs = buf.ptr;
            else
                return "Socket error " ~ to!string(err);
        }

        auto len = strlen(cs);

        if (cs[len - 1] == '\n')
            len--;
        if (cs[len - 1] == '\r')
            len--;
        return cs[0 .. len].idup;
    }
    else
    version (Windows)
    {
        return generateSysErrorMsg(err);
    }
    else
        return "Socket error " ~ to!string(err);
}

/// Returns the error message of the most recently encountered network error.
@property string lastSocketError()
{
    return formatSocketError(_lasterr());
}

/// Socket exception representing network errors reported by the operating system.
class SocketOSException: SocketException
{
    int errorCode;     /// Platform-specific error code.

    ///
    this(string msg,
         string file = __FILE__,
         size_t line = __LINE__,
         Throwable next = null,
         int err = _lasterr(),
         string function(int) @trusted errorFormatter = &formatSocketError)
    {
        errorCode = err;

        if (msg.length)
            super(msg ~ ": " ~ errorFormatter(err), file, line, next);
        else
            super(errorFormatter(err), file, line, next);
    }

    ///
    this(string msg,
         Throwable next,
         string file = __FILE__,
         size_t line = __LINE__,
         int err = _lasterr(),
         string function(int) @trusted errorFormatter = &formatSocketError)
    {
        this(msg, file, line, next, err, errorFormatter);
    }

    ///
    this(string msg,
         int err,
         string function(int) @trusted errorFormatter = &formatSocketError,
         string file = __FILE__,
         size_t line = __LINE__,
         Throwable next = null)
    {
        this(msg, file, line, next, err, errorFormatter);
    }
}

/// Socket exception representing invalid parameters specified by user code.
class SocketParameterException: SocketException
{
    mixin basicExceptionCtors;
}

/**
 * Socket exception representing attempts to use network capabilities not
 * available on the current system.
 */
class SocketFeatureException: SocketException
{
    mixin basicExceptionCtors;
}


/**
 * Returns:
 * `true` if the last socket operation failed because the socket
 * was in non-blocking mode and the operation would have blocked,
 * or if the socket is in blocking mode and set a `SNDTIMEO` or `RCVTIMEO`,
 * and the operation timed out.
 */
bool wouldHaveBlocked() nothrow @nogc
{
    version (Windows)
        return _lasterr() == WSAEWOULDBLOCK || _lasterr() == WSAETIMEDOUT;
    else version (LinuxLike)
        return _lasterr() == EAGAIN;
    else
        static assert(0, "No socket support for this platform yet.");
}


version(Windows)
{
    private immutable
    {
        typeof(&getnameinfo) getnameinfoPointer;
        typeof(&getaddrinfo) getaddrinfoPointer;
        typeof(&freeaddrinfo) freeaddrinfoPointer;
    }
}
else
{
    private immutable
    {
        typeof(&getaddrinfo) getaddrinfoPointer = &getaddrinfo;
        typeof(&freeaddrinfo) freeaddrinfoPointer = &freeaddrinfo;
        version(linux)
            typeof(&getnameinfo) getnameinfoPointer = &getnameinfo;
    }
}

shared static this() @system
{
    version (Windows)
    {
        WSADATA wd;

        // Winsock will still load if an older version is present.
        // The version is just a request.
        int val;
        val = WSAStartup(0x2020, &wd);
        if (val)         // Request Winsock 2.2 for IPv6.
            throw new SocketOSException("Unable to initialize socket library", val);

        // These functions may not be present on older Windows versions.
        // See the comment in InternetAddress.toHostNameString() for details.
        auto ws2Lib = GetModuleHandleA("ws2_32.dll");
        if (ws2Lib)
        {
            getnameinfoPointer = cast(typeof(getnameinfoPointer))
                                 GetProcAddress(ws2Lib, "getnameinfo");
            getaddrinfoPointer = cast(typeof(getaddrinfoPointer))
                                 GetProcAddress(ws2Lib, "getaddrinfo");
            freeaddrinfoPointer = cast(typeof(freeaddrinfoPointer))
                                 GetProcAddress(ws2Lib, "freeaddrinfo");
        }
    }
}



version(Windows)
{
    shared static ~this() @system nothrow @nogc
    {
        WSACleanup();
    }
}


/**
 * The communication domain used to resolve an address.
 */
enum AddressFamily: ushort
{
    UNSPEC =     AF_UNSPEC,     /// Unspecified address family
    UNIX =       AF_UNIX,       /// Local communication (Unix socket)
    INET =       AF_INET,       /// Internet Protocol version 4
    IPX =        AF_IPX,        /// Novell IPX
    APPLETALK =  AF_APPLETALK,  /// AppleTalk
    INET6 =      AF_INET6,      /// Internet Protocol version 6
}


/**
 * Communication semantics
 */
enum SocketType: int
{
    STREAM =     SOCK_STREAM,           /// Sequenced, reliable, two-way communication-based byte streams
    DGRAM =      SOCK_DGRAM,            /// Connectionless, unreliable datagrams with a fixed maximum length; data may be lost or arrive out of order
    RAW =        SOCK_RAW,              /// Raw protocol access
    RDM =        SOCK_RDM,              /// Reliably-delivered message datagrams
    SEQPACKET =  SOCK_SEQPACKET,        /// Sequenced, reliable, two-way connection-based datagrams with a fixed maximum length
}

version(PSVita)
{
    /**
    * Protocol
    */
    enum ProtocolType: int
    {
        IP =    IPPROTO_IP,         /// Internet Protocol version 4
        ICMP =  IPPROTO_ICMP,       /// Internet Control Message Protocol
        IGMP =  IPPROTO_IGMP,       /// Internet Group Management Protocol
        TCP =   IPPROTO_TCP,        /// Transmission Control Protocol
        UDP =   IPPROTO_UDP,        /// User Datagram Protocol
        IPV6 =  IPPROTO_IPV6,       /// Internet Protocol version 6

        GGP = int.max,
        PUP = int.max,
        IDP = int.max,
        RAW = int.max,        /// Raw IP packets
    }
}
else
{
    /**
    * Protocol
    */
    enum ProtocolType: int
    {
        IP =    IPPROTO_IP,         /// Internet Protocol version 4
        ICMP =  IPPROTO_ICMP,       /// Internet Control Message Protocol
        IGMP =  IPPROTO_IGMP,       /// Internet Group Management Protocol
        GGP =   IPPROTO_GGP,        /// Gateway to Gateway Protocol
        TCP =   IPPROTO_TCP,        /// Transmission Control Protocol
        PUP =   IPPROTO_PUP,        /// PARC Universal Packet Protocol
        UDP =   IPPROTO_UDP,        /// User Datagram Protocol
        IDP =   IPPROTO_IDP,        /// Xerox NS protocol
        RAW =   IPPROTO_RAW,        /// Raw IP packets
        IPV6 =  IPPROTO_IPV6,       /// Internet Protocol version 6
    }
}



/**
 * Class for retrieving protocol information.
 *
 * Example:
 * ---
 * auto proto = new Protocol;
 * writeln("About protocol TCP:");
 * if (proto.getProtocolByType(ProtocolType.TCP))
 * {
 *     writefln("  Name: %s", proto.name);
 *     foreach (string s; proto.aliases)
 *          writefln("  Alias: %s", s);
 * }
 * else
 *     writeln("  No information found");
 * ---
 */
// class Protocol
// {
//     /// These members are populated when one of the following functions are called successfully:
//     ProtocolType type;
//     string name;                /// ditto
//     string[] aliases;           /// ditto


//     void populate(protoent* proto) @system pure nothrow
//     {
//         type = cast(ProtocolType) proto.p_proto;
//         name = to!string(proto.p_name);

//         int i;
//         for (i = 0;; i++)
//         {
//             if (!proto.p_aliases[i])
//                 break;
//         }

//         if (i)
//         {
//             aliases = new string[i];
//             for (i = 0; i != aliases.length; i++)
//             {
//                 aliases[i] =
//                     to!string(proto.p_aliases[i]);
//             }
//         }
//         else
//         {
//             aliases = null;
//         }
//     }

//     /** Returns: false on failure */
//     bool getProtocolByName(scope const(char)[] name) @trusted nothrow
//     {
//         protoent* proto;
//         proto = getprotobyname(name.tempCString());
//         if (!proto)
//             return false;
//         populate(proto);
//         return true;
//     }


//     /** Returns: false on failure */
//     // Same as getprotobynumber().
//     bool getProtocolByType(ProtocolType type) @trusted nothrow
//     {
//         protoent* proto;
//         proto = getprotobynumber(type);
//         if (!proto)
//             return false;
//         populate(proto);
//         return true;
//     }
// }



/**
 * Class for retrieving service information.
 *
 * Example:
 * ---
 * auto serv = new Service;
 * writeln("About service epmap:");
 * if (serv.getServiceByName("epmap", "tcp"))
 * {
 *     writefln("  Service: %s", serv.name);
 *     writefln("  Port: %d", serv.port);
 *     writefln("  Protocol: %s", serv.protocolName);
 *     foreach (string s; serv.aliases)
 *          writefln("  Alias: %s", s);
 * }
 * else
 *     writefln("  No service for epmap.");
 * ---
 */
class Service
{
    /// These members are populated when one of the following functions are called successfully:
    string name;
    string[] aliases;           /// ditto
    ushort port;                /// ditto
    string protocolName;        /// ditto


    void populate(servent* serv) @system pure nothrow
    {
        name = to!string(serv.s_name);
        port = ntohs(cast(ushort) serv.s_port);
        protocolName = to!string(serv.s_proto);

        int i;
        for (i = 0;; i++)
        {
            if (!serv.s_aliases[i])
                break;
        }

        if (i)
        {
            aliases = new string[i];
            for (i = 0; i != aliases.length; i++)
            {
                aliases[i] =
                    to!string(serv.s_aliases[i]);
            }
        }
        else
        {
            aliases = null;
        }
    }

    /**
     * If a protocol name is omitted, any protocol will be matched.
     * Returns: false on failure.
     */
    bool getServiceByName(scope const(char)[] name, scope const(char)[] protocolName = null) @trusted nothrow
    {
        servent* serv;
        serv = getservbyname(name.tempCString(), protocolName.tempCString());
        if (!serv)
            return false;
        populate(serv);
        return true;
    }


    /// ditto
    bool getServiceByPort(ushort port, scope const(char)[] protocolName = null) @trusted nothrow
    {
        servent* serv;
        serv = getservbyport(port, protocolName.tempCString());
        if (!serv)
            return false;
        populate(serv);
        return true;
    }
}



private mixin template socketOSExceptionCtors()
{
    ///
    this(string msg, string file = __FILE__, size_t line = __LINE__,
         Throwable next = null, int err = _lasterr())
    {
        super(msg, file, line, next, err);
    }

    ///
    this(string msg, Throwable next, string file = __FILE__,
         size_t line = __LINE__, int err = _lasterr())
    {
        super(msg, next, file, line, err);
    }

    ///
    this(string msg, int err, string file = __FILE__, size_t line = __LINE__,
         Throwable next = null)
    {
        super(msg, next, file, line, err);
    }
}


/**
 * Class for exceptions thrown from an `InternetHost`.
 */
class HostException: SocketOSException
{
    mixin socketOSExceptionCtors;
}

/**
 * Class for resolving IPv4 addresses.
 *
 * Consider using `getAddress`, `parseAddress` and `Address` methods
 * instead of using this class directly.
 */
class InternetHost
{
    /// These members are populated when one of the following functions are called successfully:
    string name;
    string[] aliases;           /// ditto
    uint[] addrList;            /// ditto


    void validHostent(in hostent* he)
    {
        if (he.h_addrtype != cast(int) AddressFamily.INET || he.h_length != 4)
            throw new HostException("Address family mismatch");
    }


    void populate(hostent* he) @system pure nothrow
    {
        int i;
        char* p;

        name = to!string(he.h_name);

        for (i = 0;; i++)
        {
            p = he.h_aliases[i];
            if (!p)
                break;
        }

        if (i)
        {
            aliases = new string[i];
            for (i = 0; i != aliases.length; i++)
            {
                aliases[i] =
                    to!string(he.h_aliases[i]);
            }
        }
        else
        {
            aliases = null;
        }

        for (i = 0;; i++)
        {
            p = he.h_addr_list[i];
            if (!p)
                break;
        }

        if (i)
        {
            addrList = new uint[i];
            for (i = 0; i != addrList.length; i++)
            {
                addrList[i] = ntohl(*(cast(uint*) he.h_addr_list[i]));
            }
        }
        else
        {
            addrList = null;
        }
    }

    private bool getHostNoSync(string opMixin, T)(T param) @system
    {
        mixin(opMixin);
        if (!he)
            return false;
        validHostent(he);
        populate(he);
        return true;
    }

    version (Windows)
        alias getHost = getHostNoSync;
    else
    {
        // posix systems use global state for return value, so we
        // must synchronize across all threads
        private bool getHost(string opMixin, T)(T param) @system
        {
            // synchronized(this.classinfo)
            return getHostNoSync!(opMixin, T)(param);
        }
    }

    /**
     * Resolve host name.
     * Returns: false if unable to resolve.
     */
    bool getHostByName(scope const(char)[] name) @trusted
    {
        static if (is(typeof(gethostbyname_r)))
        {
            return getHostNoSync!q{
                hostent he_v;
                hostent* he;
                ubyte[256] buffer_v = void;
                auto buffer = buffer_v[];
                auto param_zTmp = param.tempCString();
                while (true)
                {
                    he = &he_v;
                    int errno;
                    if (gethostbyname_r(param_zTmp, he, buffer.ptr, buffer.length, &he, &errno) == ERANGE)
                        buffer.length = buffer.length * 2;
                    else
                        break;
                }
            }(name);
        }
        else
        {
            return getHost!q{
                auto he = gethostbyname(param.tempCString());
            }(name);
        }
    }

    /**
     * Resolve IPv4 address number.
     *
     * Params:
     *   addr = The IPv4 address to resolve, in host byte order.
     * Returns:
     *   false if unable to resolve.
     */
    bool getHostByAddr(uint addr) @trusted
    {
        return getHost!q{
            auto x = htonl(param);
            auto he = gethostbyaddr(&x, 4, cast(int) AddressFamily.INET);
        }(addr);
    }

    /**
     * Same as previous, but addr is an IPv4 address string in the
     * dotted-decimal form $(I a.b.c.d).
     * Returns: false if unable to resolve.
     */
    bool getHostByAddr(scope const(char)[] addr) @trusted
    {
        return getHost!q{
            auto x = inet_addr(param.tempCString());
            enforce(x != INADDR_NONE,
                new SocketParameterException("Invalid IPv4 address"));
            auto he = gethostbyaddr(&x, 4, cast(int) AddressFamily.INET);
        }(addr);
    }
}

///



/// Holds information about a socket _address retrieved by `getAddressInfo`.
struct AddressInfo
{
    AddressFamily family;   /// Address _family
    SocketType type;        /// Socket _type
    ProtocolType protocol;  /// Protocol
    Address address;        /// Socket _address
    string canonicalName;   /// Canonical name, when `AddressInfoFlags.CANONNAME` is used.
}

/**
 * A subset of flags supported on all platforms with getaddrinfo.
 * Specifies option flags for `getAddressInfo`.
 */
enum AddressInfoFlags: int
{
    /// The resulting addresses will be used in a call to `Socket.bind`.
    PASSIVE = AI_PASSIVE,

    /// The canonical name is returned in `canonicalName` member in the first `AddressInfo`.
    CANONNAME = AI_CANONNAME,

    /**
     * The `node` parameter passed to `getAddressInfo` must be a numeric string.
     * This will suppress any potentially lengthy network host address lookups.
     */
    NUMERICHOST = AI_NUMERICHOST,
}


/**
 * On POSIX, getaddrinfo uses its own error codes, and thus has its own
 * formatting function.
 */
private string formatGaiError(int err) @trusted
{
    version (Windows)
    {
        return generateSysErrorMsg(err);
    }
    else
    {
        // synchronized
            return to!string(gai_strerror(err));
    }
}

/**
 * Provides _protocol-independent translation from host names to socket
 * addresses. If advanced functionality is not required, consider using
 * `getAddress` for compatibility with older systems.
 *
 * Returns: Array with one `AddressInfo` per socket address.
 *
 * Throws: `SocketOSException` on failure, or `SocketFeatureException`
 * if this functionality is not available on the current system.
 *
 * Params:
 *  node     = string containing host name or numeric address
 *  options  = optional additional parameters, identified by type:
 *             $(UL $(LI `string` - service name or port number)
 *                  $(LI `AddressInfoFlags` - option flags)
 *                  $(LI `AddressFamily` - address family to filter by)
 *                  $(LI `SocketType` - socket type to filter by)
 *                  $(LI `ProtocolType` - protocol to filter by))
 *
 * Example:
 * ---
 * // Roundtrip DNS resolution
 * auto results = getAddressInfo("www.digitalmars.com");
 * assert(results[0].address.toHostNameString() ==
 *     "digitalmars.com");
 *
 * // Canonical name
 * results = getAddressInfo("www.digitalmars.com",
 *     AddressInfoFlags.CANONNAME);
 * assert(results[0].canonicalName == "digitalmars.com");
 *
 * // IPv6 resolution
 * results = getAddressInfo("ipv6.google.com");
 * assert(results[0].family == AddressFamily.INET6);
 *
 * // Multihomed resolution
 * results = getAddressInfo("google.com");
 * assert(results.length > 1);
 *
 * // Parsing IPv4
 * results = getAddressInfo("127.0.0.1",
 *     AddressInfoFlags.NUMERICHOST);
 * assert(results.length && results[0].family ==
 *     AddressFamily.INET);
 *
 * // Parsing IPv6
 * results = getAddressInfo("::1",
 *     AddressInfoFlags.NUMERICHOST);
 * assert(results.length && results[0].family ==
 *     AddressFamily.INET6);
 * ---
 */
AddressInfo[] getAddressInfo(T...)(scope const(char)[] node, scope T options)
{
    const(char)[] service = null;
    addrinfo hints;
    hints.ai_family = AF_UNSPEC;

    foreach (i, option; options)
    {
        static if (is(typeof(option) : const(char)[]))
            service = options[i];
        else
        static if (is(typeof(option) == AddressInfoFlags))
            hints.ai_flags |= option;
        else
        static if (is(typeof(option) == AddressFamily))
            hints.ai_family = option;
        else
        static if (is(typeof(option) == SocketType))
            hints.ai_socktype = option;
        else
        static if (is(typeof(option) == ProtocolType))
            hints.ai_protocol = option;
        else
            static assert(0, "Unknown getAddressInfo option type: " ~ typeof(option).stringof);
    }

    return () @trusted { return getAddressInfoImpl(node, service, &hints); }();
}


private AddressInfo[] getAddressInfoImpl(scope const(char)[] node, scope const(char)[] service, addrinfo* hints) @system
{

    if (getaddrinfoPointer && freeaddrinfoPointer)
    {
        addrinfo* ai_res;

        int ret = getaddrinfoPointer(
            node.tempCString(),
            service.tempCString(),
            hints, &ai_res);
        enforce(ret == 0, new SocketOSException("getaddrinfo error", ret, &formatGaiError));
        scope(exit) freeaddrinfoPointer(ai_res);

        AddressInfo[] result;

        // Use const to force UnknownAddressReference to copy the sockaddr.
        for (const(addrinfo)* ai = ai_res; ai; ai = ai.ai_next)
            result ~= AddressInfo(
                cast(AddressFamily) ai.ai_family,
                cast(SocketType   ) ai.ai_socktype,
                cast(ProtocolType ) ai.ai_protocol,
                new UnknownAddressReference(ai.ai_addr, cast(socklen_t) ai.ai_addrlen),
                ai.ai_canonname ? to!string(ai.ai_canonname) : null);

        return result;
    }

    throw new SocketFeatureException("Address info lookup is not available " ~
        "on this system.");
}



private ushort serviceToPort(scope const(char)[] service)
{
    if (service == "")
        return InternetAddress.PORT_ANY;
    else
    if (isNumber(service))
        return to!ushort(service);
    else
    {
        auto s = new Service();
        s.getServiceByName(service);
        return s.port;
    }
}

/**
 * Provides _protocol-independent translation from host names to socket
 * addresses. Uses `getAddressInfo` if the current system supports it,
 * and `InternetHost` otherwise.
 *
 * Returns: Array with one `Address` instance per socket address.
 *
 * Throws: `SocketOSException` on failure.
 *
 * Example:
 * ---
 * writeln("Resolving www.digitalmars.com:");
 * try
 * {
 *     auto addresses = getAddress("www.digitalmars.com");
 *     foreach (address; addresses)
 *         writefln("  IP: %s", address.toAddrString());
 * }
 * catch (SocketException e)
 *     writefln("  Lookup failed: %s", e.msg);
 * ---
 */
Address[] getAddress(scope const(char)[] hostname, scope const(char)[] service = null)
{
    if (getaddrinfoPointer && freeaddrinfoPointer)
    {
        // use getAddressInfo
        auto infos = getAddressInfo(hostname, service);
        Address[] results;
        results.length = infos.length;
        foreach (i, ref result; results)
            result = infos[i].address;
        return results;
    }
    else
        return getAddress(hostname, serviceToPort(service));
}

/// ditto
Address[] getAddress(scope const(char)[] hostname, ushort port)
{
    if (getaddrinfoPointer && freeaddrinfoPointer)
        return getAddress(hostname, to!string(port));
    else
    {
        // use getHostByName
        auto ih = new InternetHost;
        if (!ih.getHostByName(hostname))
        {
            throw new AddressException(
                        cast(string)("Unable to resolve host '" ~hostname.idup ~"'"));
        }

        Address[] results;
        foreach (uint addr; ih.addrList)
            results ~= new InternetAddress(addr, port);
        return results;
    }
}





/**
 * Provides _protocol-independent parsing of network addresses. Does not
 * attempt name resolution. Uses `getAddressInfo` with
 * `AddressInfoFlags.NUMERICHOST` if the current system supports it, and
 * `InternetAddress` otherwise.
 *
 * Returns: An `Address` instance representing specified address.
 *
 * Throws: `SocketException` on failure.
 *
 * Example:
 * ---
 * writeln("Enter IP address:");
 * string ip = readln().chomp();
 * try
 * {
 *     Address address = parseAddress(ip);
 *     writefln("Looking up reverse of %s:",
 *         address.toAddrString());
 *     try
 *     {
 *         string reverse = address.toHostNameString();
 *         if (reverse)
 *             writefln("  Reverse name: %s", reverse);
 *         else
 *             writeln("  Reverse hostname not found.");
 *     }
 *     catch (SocketException e)
 *         writefln("  Lookup error: %s", e.msg);
 * }
 * catch (SocketException e)
 * {
 *     writefln("  %s is not a valid IP address: %s",
 *         ip, e.msg);
 * }
 * ---
 */
Address parseAddress(scope const(char)[] hostaddr, scope const(char)[] service = null)
{
    if (getaddrinfoPointer && freeaddrinfoPointer)
        return getAddressInfo(hostaddr, service, AddressInfoFlags.NUMERICHOST)[0].address;
    else
        return parseAddress(hostaddr, serviceToPort(service));
}

/// ditto
Address parseAddress(scope const(char)[] hostaddr, ushort port)
{
    if (getaddrinfoPointer && freeaddrinfoPointer)
        return parseAddress(hostaddr, to!string(port));
    else
    {
        auto in4_addr = InternetAddress.parse(hostaddr);
        enforce(in4_addr != InternetAddress.ADDR_NONE,
            new SocketParameterException("Invalid IP address"));
        return new InternetAddress(in4_addr, port);
    }
}



/**
 * Class for exceptions thrown from an `Address`.
 */
class AddressException: SocketOSException
{
    mixin socketOSExceptionCtors;
}


/**
 * Abstract class for representing a socket address.
 *
 * Example:
 * ---
 * writeln("About www.google.com port 80:");
 * try
 * {
 *     Address[] addresses = getAddress("www.google.com", 80);
 *     writefln("  %d addresses found.", addresses.length);
 *     foreach (int i, Address a; addresses)
 *     {
 *         writefln("  Address %d:", i+1);
 *         writefln("    IP address: %s", a.toAddrString());
 *         writefln("    Hostname: %s", a.toHostNameString());
 *         writefln("    Port: %s", a.toPortString());
 *         writefln("    Service name: %s",
 *             a.toServiceNameString());
 *     }
 * }
 * catch (SocketException e)
 *     writefln("  Lookup error: %s", e.msg);
 * ---
 */
abstract class Address
{
    /// Returns pointer to underlying `sockaddr` structure.
    abstract @property sockaddr* name() pure nothrow @nogc;
    abstract @property const(sockaddr)* name() const pure nothrow @nogc; /// ditto

    /// Returns actual size of underlying `sockaddr` structure.
    abstract @property socklen_t nameLen() const pure nothrow @nogc;

    // Socket.remoteAddress, Socket.localAddress, and Socket.receiveFrom
    // use setNameLen to set the actual size of the address as returned by
    // getsockname, getpeername, and recvfrom, respectively.
    // The following implementation is sufficient for fixed-length addresses,
    // and ensures that the length is not changed.
    // Must be overridden for variable-length addresses.
    protected void setNameLen(socklen_t len)
    {
        if (len != this.nameLen)
            throw new AddressException(typeid(this).toString ~ " expects address of length "~nameLen.to!string~", not "~len.to!string, 0);
    }

    /// Family of this address.
    @property AddressFamily addressFamily() const pure nothrow @nogc
    {
        return cast(AddressFamily) name.sa_family;
    }

    // Common code for toAddrString and toHostNameString
    private string toHostString(bool numeric) @trusted const
    {
        // getnameinfo() is the recommended way to perform a reverse (name)
        // lookup on both Posix and Windows. However, it is only available
        // on Windows XP and above, and not included with the WinSock import
        // libraries shipped with DMD. Thus, we check for getnameinfo at
        // runtime in the shared module constructor, and use it if it's
        // available in the base class method. Classes for specific network
        // families (e.g. InternetHost) override this method and use a
        // deprecated, albeit commonly-available method when getnameinfo()
        // is not available.
        // http://technet.microsoft.com/en-us/library/aa450403.aspx

        throw new SocketFeatureException((numeric ? "Host address" : "Host name") ~
            " lookup for this address family is not available on this system.");
    }

    // Common code for toPortString and toServiceNameString
    private string toServiceString(bool numeric) @trusted const
    {
        // See toHostNameString() for details about getnameinfo().

        throw new SocketFeatureException((numeric ? "Port number" : "Service name") ~
            " lookup for this address family is not available on this system.");
    }

    /**
     * Attempts to retrieve the host address as a human-readable string.
     *
     * Throws: `AddressException` on failure, or `SocketFeatureException`
     * if address retrieval for this address family is not available on the
     * current system.
     */
    string toAddrString() const
    {
        return toHostString(true);
    }

    /**
     * Attempts to retrieve the host name as a fully qualified domain name.
     *
     * Returns: The FQDN corresponding to this `Address`, or `null` if
     * the host name did not resolve.
     *
     * Throws: `AddressException` on error, or `SocketFeatureException`
     * if host name lookup for this address family is not available on the
     * current system.
     */
    string toHostNameString() const
    {
        return toHostString(false);
    }

    /**
     * Attempts to retrieve the numeric port number as a string.
     *
     * Throws: `AddressException` on failure, or `SocketFeatureException`
     * if port number retrieval for this address family is not available on the
     * current system.
     */
    string toPortString() const
    {
        return toServiceString(true);
    }

    /**
     * Attempts to retrieve the service name as a string.
     *
     * Throws: `AddressException` on failure, or `SocketFeatureException`
     * if service name lookup for this address family is not available on the
     * current system.
     */
    string toServiceNameString() const
    {
        return toServiceString(false);
    }

    /// Human readable string representing this address.
    override string toString() const
    {
        try
        {
            string host = toAddrString();
            string port = toPortString();
            if (host.indexOf(":") >= 0)
                return "[" ~ host ~ "]:" ~ port;
            else
                return host ~ ":" ~ port;
        }
        catch (SocketException)
            return "Unknown";
    }
}

/**
 * Encapsulates an unknown socket address.
 */
class UnknownAddress: Address
{
protected:
    sockaddr sa;


public:
    override @property sockaddr* name() return
    {
        return &sa;
    }

    override @property const(sockaddr)* name() const return
    {
        return &sa;
    }


    override @property socklen_t nameLen() const
    {
        return cast(socklen_t) sa.sizeof;
    }

}


/**
 * Encapsulates a reference to an arbitrary
 * socket address.
 */
class UnknownAddressReference: Address
{
protected:
    sockaddr* sa;
    socklen_t len;

public:
    /// Constructs an `Address` with a reference to the specified `sockaddr`.
    this(sockaddr* sa, socklen_t len) pure nothrow @nogc
    {
        this.sa  = sa;
        this.len = len;
    }

    /// Constructs an `Address` with a copy of the specified `sockaddr`.
    this(const(sockaddr)* sa, socklen_t len) @system pure nothrow
    {
        this.sa = cast(sockaddr*) (cast(ubyte*) sa)[0 .. len].dup.ptr;
        this.len = len;
    }

    override @property sockaddr* name()
    {
        return sa;
    }

    override @property const(sockaddr)* name() const
    {
        return sa;
    }


    override @property socklen_t nameLen() const
    {
        return cast(socklen_t) len;
    }
}


/**
 * Encapsulates an IPv4 (Internet Protocol version 4) socket address.
 *
 * Consider using `getAddress`, `parseAddress` and `Address` methods
 * instead of using this class directly.
 */
class InternetAddress: Address
{
protected:
    sockaddr_in sin;


    this() pure nothrow @nogc
    {
    }


public:
    override @property sockaddr* name() return
    {
        return cast(sockaddr*)&sin;
    }

    override @property const(sockaddr)* name() const return
    {
        return cast(const(sockaddr)*)&sin;
    }


    override @property socklen_t nameLen() const
    {
        return cast(socklen_t) sin.sizeof;
    }


    enum uint ADDR_ANY = INADDR_ANY;         /// Any IPv4 host address.
    enum uint ADDR_NONE = INADDR_NONE;       /// An invalid IPv4 host address.
    enum ushort PORT_ANY = 0;                /// Any IPv4 port number.

    /// Returns the IPv4 _port number (in host byte order).
    @property ushort port() const pure nothrow @nogc
    {
        return ntohs(sin.sin_port);
    }

    /// Returns the IPv4 address number (in host byte order).
    @property uint addr() const pure nothrow @nogc
    {
        return ntohl(sin.sin_addr.s_addr);
    }

    /**
     * Construct a new `InternetAddress`.
     * Params:
     *   addr = an IPv4 address string in the dotted-decimal form a.b.c.d,
     *          or a host name which will be resolved using an `InternetHost`
     *          object.
     *   port = port number, may be `PORT_ANY`.
     */
    this(scope const(char)[] addr, ushort port)
    {
        uint uiaddr = parse(addr);
        if (ADDR_NONE == uiaddr)
        {
            InternetHost ih = new InternetHost;
            if (!ih.getHostByName(addr))
                //throw new AddressException("Invalid internet address");
                throw new AddressException(
                          "Unable to resolve host '"~ addr.idup~ "'");
            uiaddr = ih.addrList[0];
        }
        sin.sin_family = AddressFamily.INET;
        sin.sin_addr.s_addr = htonl(uiaddr);
        sin.sin_port = htons(port);
    }

    /**
     * Construct a new `InternetAddress`.
     * Params:
     *   addr = (optional) an IPv4 address in host byte order, may be `ADDR_ANY`.
     *   port = port number, may be `PORT_ANY`.
     */
    this(uint addr, ushort port) pure nothrow @nogc
    {
        sin.sin_family = AddressFamily.INET;
        sin.sin_addr.s_addr = htonl(addr);
        sin.sin_port = htons(port);
    }

    /// ditto
    this(ushort port) pure nothrow @nogc
    {
        sin.sin_family = AddressFamily.INET;
        sin.sin_addr.s_addr = ADDR_ANY;
        sin.sin_port = htons(port);
    }

    /**
     * Construct a new `InternetAddress`.
     * Params:
     *   addr = A sockaddr_in as obtained from lower-level API calls such as getifaddrs.
     */
    this(sockaddr_in addr) pure nothrow @nogc
    {
        assert(addr.sin_family == AddressFamily.INET, "Socket address is not of INET family.");
        sin = addr;
    }

    /// Human readable string representing the IPv4 address in dotted-decimal form.
    override string toAddrString() @trusted const
    {
        return to!string(inet_ntoa(sin.sin_addr));
    }

    /// Human readable string representing the IPv4 port.
    override string toPortString() const
    {
        return to!string(port);
    }

    /**
     * Attempts to retrieve the host name as a fully qualified domain name.
     *
     * Returns: The FQDN corresponding to this `InternetAddress`, or
     * `null` if the host name did not resolve.
     *
     * Throws: `AddressException` on error.
     */
    override string toHostNameString() const
    {
        // getnameinfo() is the recommended way to perform a reverse (name)
        // lookup on both Posix and Windows. However, it is only available
        // on Windows XP and above, and not included with the WinSock import
        // libraries shipped with DMD. Thus, we check for getnameinfo at
        // runtime in the shared module constructor, and fall back to the
        // deprecated getHostByAddr() if it could not be found. See also:
        // http://technet.microsoft.com/en-us/library/aa450403.aspx

        auto host = new InternetHost();
        if (!host.getHostByAddr(ntohl(sin.sin_addr.s_addr)))
            return null;
        return host.name;
    }

    /**
     * Provides support for comparing equality with another
     * InternetAddress of the same type.
     * Returns: true if the InternetAddresses share the same address and
     * port number.
     */
    override bool opEquals(Object o) const
    {
        auto other = cast(InternetAddress) o;
        return other && this.sin.sin_addr.s_addr == other.sin.sin_addr.s_addr &&
            this.sin.sin_port == other.sin.sin_port;
    }

    ///


    /**
     * Parse an IPv4 address string in the dotted-decimal form $(I a.b.c.d)
     * and return the number.
     * Returns: If the string is not a legitimate IPv4 address,
     * `ADDR_NONE` is returned.
     */
    static uint parse(scope const(char)[] addr) @trusted nothrow
    {
        return ntohl(inet_addr(addr.tempCString()));
    }

    /**
     * Convert an IPv4 address number in host byte order to a human readable
     * string representing the IPv4 address in dotted-decimal form.
     */
    static string addrToString(uint addr) @trusted nothrow
    {
        in_addr sin_addr;
        sin_addr.s_addr = htonl(addr);
        return to!string(inet_ntoa(sin_addr));
    }
}



/**
 * Encapsulates an IPv6 (Internet Protocol version 6) socket address.
 *
 * Consider using `getAddress`, `parseAddress` and `Address` methods
 * instead of using this class directly.
 */
class Internet6Address: Address
{
protected:
    sockaddr_in6 sin6;


    this() pure nothrow @nogc
    {
    }


public:
    override @property sockaddr* name() return
    {
        return cast(sockaddr*)&sin6;
    }

    override @property const(sockaddr)* name() const return
    {
        return cast(const(sockaddr)*)&sin6;
    }


    override @property socklen_t nameLen() const
    {
        return cast(socklen_t) sin6.sizeof;
    }

    __gshared immutable in6_addr in6addr_any = {[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]};

    /// Any IPv6 host address.
    static @property ref const(ubyte)[16] ADDR_ANY() pure nothrow @nogc
    {
        static if (is(typeof(IN6ADDR_ANY)))
        {
            version (Windows)
            {
                static immutable addr = IN6ADDR_ANY.s6_addr;
                return addr;
            }
            else
                return IN6ADDR_ANY.s6_addr;
        }
        else static if (is(typeof(in6addr_any)))
        {
            return in6addr_any.s6_addr;
        }
        else
        {
            return in6addr_any;
        }
    }

    /// Any IPv6 port number.
    enum ushort PORT_ANY = 0;

    /// Returns the IPv6 port number.
    @property ushort port() const pure nothrow @nogc
    {
        return ntohs(sin6.sin6_port);
    }

    /// Returns the IPv6 address.
    @property ubyte[16] addr() const pure nothrow @nogc
    {
        return sin6.sin6_addr.s6_addr;
    }

    /**
     * Construct a new `Internet6Address`.
     * Params:
     *   addr    = an IPv6 host address string in the form described in RFC 2373,
     *             or a host name which will be resolved using `getAddressInfo`.
     *   service = (optional) service name.
     */
    this(scope const(char)[] addr, scope const(char)[] service = null) @trusted
    {
        auto results = getAddressInfo(addr, service, AddressFamily.INET6);
        assert(results.length && results[0].family == AddressFamily.INET6);
        sin6 = *cast(sockaddr_in6*) results[0].address.name;
    }

    /**
     * Construct a new `Internet6Address`.
     * Params:
     *   addr = an IPv6 host address string in the form described in RFC 2373,
     *          or a host name which will be resolved using `getAddressInfo`.
     *   port = port number, may be `PORT_ANY`.
     */
    this(scope const(char)[] addr, ushort port)
    {
        if (port == PORT_ANY)
            this(addr);
        else
            this(addr, to!string(port));
    }

    /**
     * Construct a new `Internet6Address`.
     * Params:
     *   addr = (optional) an IPv6 host address in host byte order, or
     *          `ADDR_ANY`.
     *   port = port number, may be `PORT_ANY`.
     */
    this(ubyte[16] addr, ushort port) pure nothrow @nogc
    {
        sin6.sin6_family = AddressFamily.INET6;
        sin6.sin6_addr.s6_addr = addr;
        sin6.sin6_port = htons(port);
    }

    /// ditto
    this(ushort port) pure nothrow @nogc
    {
        sin6.sin6_family = AddressFamily.INET6;
        sin6.sin6_addr.s6_addr = ADDR_ANY;
        sin6.sin6_port = htons(port);
    }

     /**
     * Construct a new `Internet6Address`.
     * Params:
     *   addr = A sockaddr_in6 as obtained from lower-level API calls such as getifaddrs.
     */
    this(sockaddr_in6 addr) pure nothrow @nogc
    {
        assert(addr.sin6_family == AddressFamily.INET6);
        sin6 = addr;
    }

   /**
     * Parse an IPv6 host address string as described in RFC 2373, and return the
     * address.
     * Throws: `SocketException` on error.
     */
    static ubyte[16] parse(scope const(char)[] addr) @trusted
    {
        // Although we could use inet_pton here, it's only available on Windows
        // versions starting with Vista, so use getAddressInfo with NUMERICHOST
        // instead.
        auto results = getAddressInfo(addr, AddressInfoFlags.NUMERICHOST);
        if (results.length && results[0].family == AddressFamily.INET6)
            return (cast(sockaddr_in6*) results[0].address.name).sin6_addr.s6_addr;
        throw new AddressException("Not an IPv6 address", 0);
    }
}



version (StdDdoc)
{
    static if (!is(sockaddr_un))
    {
        // This exists only to allow the constructor taking
        // a sockaddr_un to be compilable for documentation
        // on platforms that don't supply a sockaddr_un.
        struct sockaddr_un
        {
        }
    }

    /**
     * Encapsulates an address for a Unix domain socket (`AF_UNIX`),
     * i.e. a socket bound to a path name in the file system.
     * Available only on supported systems.
     *
     * Linux also supports an abstract address namespace, in which addresses
     * are independent of the file system. A socket address is abstract
     * iff `path` starts with a _null byte (`'\0'`). Null bytes in other
     * positions of an abstract address are allowed and have no special
     * meaning.
     *
     * Example:
     * ---
     * auto addr = new UnixAddress("/var/run/dbus/system_bus_socket");
     * auto abstractAddr = new UnixAddress("\0/tmp/dbus-OtHLWmCLPR");
     * ---
     *
     * See_Also: $(HTTP man7.org/linux/man-pages/man7/unix.7.html, UNIX(7))
     */
    class UnixAddress: Address
    {
        private this() pure nothrow @nogc {}

        /// Construct a new `UnixAddress` from the specified path.
        this(scope const(char)[] path) { }

        /**
         * Construct a new `UnixAddress`.
         * Params:
         *   addr = A sockaddr_un as obtained from lower-level API calls.
         */
        this(sockaddr_un addr) pure nothrow @nogc { }

        /// Get the underlying _path.
        @property string path() const { return null; }

        /// ditto
        override string toString() const { return null; }

        override @property sockaddr* name() { return null; }
        override @property const(sockaddr)* name() const { return null; }
        override @property socklen_t nameLen() const { return 0; }
    }
}
else
static if (is(sockaddr_un))
{
    class UnixAddress: Address
    {
    protected:
        socklen_t _nameLen;

        struct
        {
        align (1):
            sockaddr_un sun;
            char unused = '\0'; // placeholder for a terminating '\0'
        }

        this() pure nothrow @nogc
        {
            sun.sun_family = AddressFamily.UNIX;
            sun.sun_path = '?';
            _nameLen = sun.sizeof;
        }

        override void setNameLen(socklen_t len) @trusted
        {
            if (len > sun.sizeof)
                throw new SocketParameterException("Not enough socket address storage");
            _nameLen = len;
        }

    public:
        override @property sockaddr* name() return
        {
            return cast(sockaddr*)&sun;
        }

        override @property const(sockaddr)* name() const return
        {
            return cast(const(sockaddr)*)&sun;
        }

        override @property socklen_t nameLen() @trusted const
        {
            return _nameLen;
        }

        this(scope const(char)[] path) @trusted pure
        {
            enforce(path.length <= sun.sun_path.sizeof, new SocketParameterException("Path too long"));
            sun.sun_family = AddressFamily.UNIX;
            sun.sun_path.ptr[0 .. path.length] = (cast(byte[]) path)[];
            _nameLen = cast(socklen_t)
                {
                    auto len = sockaddr_un.init.sun_path.offsetof + path.length;
                    // Pathname socket address must be terminated with '\0'
                    // which must be included in the address length.
                    if (sun.sun_path.ptr[0])
                    {
                        sun.sun_path.ptr[path.length] = 0;
                        ++len;
                    }
                    return len;
                }();
        }

        this(sockaddr_un addr) pure nothrow @nogc
        {
            assert(addr.sun_family == AddressFamily.UNIX);
            sun = addr;
        }

        @property string path() @trusted const pure
        {
            auto len = _nameLen - sockaddr_un.init.sun_path.offsetof;
            if (len == 0)
                return null; // An empty path may be returned from getpeername
            // For pathname socket address we need to strip off the terminating '\0'
            if (sun.sun_path.ptr[0])
                --len;
            return (cast(const(char)*) sun.sun_path.ptr)[0 .. len].idup;
        }

        override string toString() const pure
        {
            return path;
        }
    }

}


/**
 * Exception thrown by `Socket.accept`.
 */
class SocketAcceptException: SocketOSException
{
    mixin socketOSExceptionCtors;
}

/// How a socket is shutdown:
enum SocketShutdown: int
{
    RECEIVE =  SD_RECEIVE,      /// socket receives are disallowed
    SEND =     SD_SEND,         /// socket sends are disallowed
    BOTH =     SD_BOTH,         /// both RECEIVE and SEND
}


/// Socket flags that may be OR'ed together:
enum SocketFlags: int
{
    NONE =       0,                 /// no flags specified

    OOB =        MSG_OOB,           /// out-of-band stream data
    PEEK =       MSG_PEEK,          /// peek at incoming data without removing it from the queue, only for receiving
    DONTROUTE =  MSG_DONTROUTE,     /// data should not be subject to routing; this flag may be ignored. Only for sending
}

import core.stdc.time:time_t;

struct timeval
{
    time_t  tv_sec;
    long    tv_usec;
}


// /// Duration timeout value.
struct TimeVal
{
    timeval ctimeval;
    alias tv_sec_t = typeof(ctimeval.tv_sec);
    alias tv_usec_t = typeof(ctimeval.tv_usec);

    /// Number of _seconds.
    pure nothrow @nogc @property
    ref inout(tv_sec_t) seconds() inout return
    {
        return ctimeval.tv_sec;
    }

    /// Number of additional _microseconds.
    pure nothrow @nogc @property
    ref inout(tv_usec_t) microseconds() inout return
    {
        return ctimeval.tv_usec;
    }
}


/**
 * A collection of sockets for use with `Socket.select`.
 *
 * `SocketSet` wraps the platform `fd_set` type. However, unlike
 * `fd_set`, `SocketSet` is not statically limited to `FD_SETSIZE`
 * or any other limit, and grows as needed.
 */
class SocketSet
{
private:
    version (Windows)
    {
        // On Windows, fd_set is an array of socket handles,
        // following a word containing the fd_set instance size.
        // We use one dynamic array for everything, and use its first
        // element(s) for the count.

        alias fd_set_count_type = typeof(fd_set.init.fd_count);
        alias fd_set_type = typeof(fd_set.init.fd_array[0]);
        static assert(fd_set_type.sizeof == socket_t.sizeof);

        // Number of fd_set_type elements at the start of our array that are
        // used for the socket count and alignment

        enum FD_SET_OFFSET = fd_set.fd_array.offsetof / fd_set_type.sizeof;
        static assert(FD_SET_OFFSET);
        static assert(fd_set.fd_count.offsetof % fd_set_type.sizeof == 0);

        fd_set_type[] set;

        void resize(size_t size) pure nothrow
        {
            set.length = FD_SET_OFFSET + size;
        }

        ref inout(fd_set_count_type) count() @trusted @property inout pure nothrow @nogc
        {
            assert(set.length);
            return *cast(inout(fd_set_count_type)*)set.ptr;
        }

        size_t capacity() @property const pure nothrow @nogc
        {
            return set.length - FD_SET_OFFSET;
        }

        inout(socket_t)[] fds() @trusted inout @property pure nothrow @nogc
        {
            return cast(inout(socket_t)[])set[FD_SET_OFFSET .. FD_SET_OFFSET+count];
        }
    }
    else
    version (LinuxLike)
    {
        // On Posix, fd_set is a bit array. We assume that the fd_set
        // type (declared in core.sys.posix.sys.select) is a structure
        // containing a single field, a static array.

        static assert(fd_set.tupleof.length == 1);

        // This is the type used in the fd_set array.
        // Using the type of the correct size is important for big-endian
        // architectures.

        alias fd_set_type = typeof(fd_set.init.tupleof[0][0]);

        // Number of file descriptors represented by one fd_set_type

        enum FD_NFDBITS = 8 * fd_set_type.sizeof;

        static fd_set_type mask(uint n) pure nothrow @nogc
        {
            return (cast(fd_set_type) 1) << (n % FD_NFDBITS);
        }

        // Array size to fit that many sockets

        static size_t lengthFor(size_t size) pure nothrow @nogc
        {
            return (size + (FD_NFDBITS-1)) / FD_NFDBITS;
        }

        fd_set_type[] set;

        void resize(size_t size) pure nothrow
        {
            set.length = lengthFor(size);
        }

        // Make sure we can fit that many sockets

        void setMinCapacity(size_t size) pure nothrow
        {
            auto length = lengthFor(size);
            if (set.length < length)
                set.length = length;
        }

        size_t capacity() @property const pure nothrow @nogc
        {
            return set.length * FD_NFDBITS;
        }

        int maxfd;
    }
    else
        static assert(false, "Unknown platform");

public:

    /**
     * Create a SocketSet with a specific initial capacity (defaults to
     * `FD_SETSIZE`, the system's default capacity).
     */
    this(size_t size = FD_SETSIZE) pure nothrow
    {
        resize(size);
        reset();
    }

    /// Reset the `SocketSet` so that there are 0 `Socket`s in the collection.
    void reset() pure nothrow @nogc
    {
        version (Windows)
            count = 0;
        else
        {
            set[] = 0;
            maxfd = -1;
        }
    }


    void add(socket_t s) @trusted pure nothrow
    {
        version (Windows)
        {
            if (count == capacity)
            {
                set.length *= 2;
                set.length = set.capacity;
            }
            ++count;
            fds[$-1] = s;
        }
        else
        {
            auto index = s / FD_NFDBITS;
            auto length = set.length;
            if (index >= length)
            {
                while (index >= length)
                    length *= 2;
                set.length = length;
                // set.length = set.capacity;
            }
            set[index] |= mask(s);
            if (maxfd < s)
                maxfd = s;
        }
    }

    /**
     * Add a `Socket` to the collection.
     * The socket must not already be in the collection.
     */
    void add(Socket s) pure nothrow
    {
        add(s.sock);
    }

    void remove(socket_t s) pure nothrow
    {
        version (Windows)
        {
            import std.algorithm.searching : countUntil;
            auto fds = fds;
            auto p = fds.countUntil(s);
            if (p >= 0)
                fds[p] = fds[--count];
        }
        else
        {
            auto index = s / FD_NFDBITS;
            if (index >= set.length)
                return;
            set[index] &= ~mask(s);
            // note: adjusting maxfd would require scanning the set, not worth it
        }
    }


    /**
     * Remove this `Socket` from the collection.
     * Does nothing if the socket is not in the collection already.
     */
    void remove(Socket s) pure nothrow
    {
        remove(s.sock);
    }

    int isSet(socket_t s) const pure nothrow @nogc
    {
        version (Windows)
        {
            import std.algorithm.searching : canFind;
            return fds.canFind(s) ? 1 : 0;
        }
        else
        {
            if (s > maxfd)
                return 0;
            auto index = s / FD_NFDBITS;
            return (set[index] & mask(s)) ? 1 : 0;
        }
    }


    /// Return nonzero if this `Socket` is in the collection.
    int isSet(Socket s) const pure nothrow @nogc
    {
        return isSet(s.sock);
    }


    /**
     * Returns:
     * The current capacity of this `SocketSet`. The exact
     * meaning of the return value varies from platform to platform.
     *
     * Note:
     * Since D 2.065, this value does not indicate a
     * restriction, and `SocketSet` will grow its capacity as
     * needed automatically.
     */
    @property uint max() const pure nothrow @nogc
    {
        return cast(uint) capacity;
    }


    fd_set* toFd_set() @trusted pure nothrow @nogc
    {
        return cast(fd_set*) set.ptr;
    }


    int selectn() const pure nothrow @nogc
    {
        version (Windows)
        {
            return count;
        }
        else version (LinuxLike)
        {
            return maxfd + 1;
        }
    }
}

/// The level at which a socket option is defined:
enum SocketOptionLevel: int
{
    SOCKET =  SOL_SOCKET,               /// Socket level
    IP =      ProtocolType.IP,          /// Internet Protocol version 4 level
    ICMP =    ProtocolType.ICMP,        /// Internet Control Message Protocol level
    IGMP =    ProtocolType.IGMP,        /// Internet Group Management Protocol level
    GGP =     ProtocolType.GGP,         /// Gateway to Gateway Protocol level
    TCP =     ProtocolType.TCP,         /// Transmission Control Protocol level
    PUP =     ProtocolType.PUP,         /// PARC Universal Packet Protocol level
    UDP =     ProtocolType.UDP,         /// User Datagram Protocol level
    IDP =     ProtocolType.IDP,         /// Xerox NS protocol level
    RAW =     ProtocolType.RAW,         /// Raw IP packet level
    IPV6 =    ProtocolType.IPV6,        /// Internet Protocol version 6 level
}

/// _Linger information for use with SocketOption.LINGER.
// struct Linger
// {
//     _clinger clinger;

//     private alias l_onoff_t = typeof(_clinger.init.l_onoff );
//     private alias l_linger_t = typeof(_clinger.init.l_linger);

//     /// Nonzero for _on.
//     pure nothrow @nogc @property
//     ref inout(l_onoff_t) on() inout return
//     {
//         return clinger.l_onoff;
//     }

//     /// Linger _time.
//     pure nothrow @nogc @property
//     ref inout(l_linger_t) time() inout return
//     {
//         return clinger.l_linger;
//     }
// }

/// Specifies a socket option:
enum SocketOption: int
{
    DEBUG =                SO_DEBUG,            /// Record debugging information
    BROADCAST =            SO_BROADCAST,        /// Allow transmission of broadcast messages
    REUSEADDR =            SO_REUSEADDR,        /// Allow local reuse of address
    LINGER =               SO_LINGER,           /// Linger on close if unsent data is present
    OOBINLINE =            SO_OOBINLINE,        /// Receive out-of-band data in band
    SNDBUF =               SO_SNDBUF,           /// Send buffer size
    RCVBUF =               SO_RCVBUF,           /// Receive buffer size
    DONTROUTE =            SO_DONTROUTE,        /// Do not route
    SNDTIMEO =             SO_SNDTIMEO,         /// Send timeout
    RCVTIMEO =             SO_RCVTIMEO,         /// Receive timeout
    ERROR =                SO_ERROR,            /// Retrieve and clear error status
    KEEPALIVE =            SO_KEEPALIVE,        /// Enable keep-alive packets
    ACCEPTCONN =           SO_ACCEPTCONN,       /// Listen
    RCVLOWAT =             SO_RCVLOWAT,         /// Minimum number of input bytes to process
    SNDLOWAT =             SO_SNDLOWAT,         /// Minimum number of output bytes to process
    TYPE =                 SO_TYPE,             /// Socket type

    // SocketOptionLevel.TCP:
    TCP_NODELAY =          .TCP_NODELAY,        /// Disable the Nagle algorithm for send coalescing

    // SocketOptionLevel.IPV6:
    IPV6_UNICAST_HOPS =    .IPV6_UNICAST_HOPS,          /// IP unicast hop limit
    IPV6_MULTICAST_IF =    .IPV6_MULTICAST_IF,          /// IP multicast interface
    IPV6_MULTICAST_LOOP =  .IPV6_MULTICAST_LOOP,        /// IP multicast loopback
    IPV6_MULTICAST_HOPS =  .IPV6_MULTICAST_HOPS,        /// IP multicast hops
    IPV6_JOIN_GROUP =      .IPV6_JOIN_GROUP,            /// Add an IP group membership
    IPV6_LEAVE_GROUP =     .IPV6_LEAVE_GROUP,           /// Drop an IP group membership
    IPV6_V6ONLY =          .IPV6_V6ONLY,                /// Treat wildcard bind as AF_INET6-only
}


/**
 * Class that creates a network communication endpoint using
 * the Berkeley sockets interface.
 */
class Socket
{
private:
    socket_t sock;
    AddressFamily _family;

    version (Windows)
        bool _blocking = true;         /// Property to get or set whether the socket is blocking or nonblocking.

    // The WinSock timeouts seem to be effectively skewed by a constant
    // offset of about half a second (value in milliseconds). This has
    // been confirmed on updated (as of Jun 2011) Windows XP, Windows 7
    // and Windows Server 2008 R2 boxes. The unittest below tests this
    // behavior.
    enum WINSOCK_TIMEOUT_SKEW = 500;

    void setSock(socket_t handle)
    {
        assert(handle != socket_t.init);
        sock = handle;

        // Set the option to disable SIGPIPE on send() if the platform
        // has it (e.g. on OS X).
        static if (is(typeof(SO_NOSIGPIPE)))
        {
            setOption(SocketOptionLevel.SOCKET, cast(SocketOption) SO_NOSIGPIPE, true);
        }
    }


    // For use with accepting().
    protected this() pure nothrow @nogc
    {
    }


public:

    /**
     * Create a blocking socket. If a single protocol type exists to support
     * this socket type within the address family, the `ProtocolType` may be
     * omitted.
     */
    this(AddressFamily af, SocketType type, ProtocolType protocol) @trusted
    {
        _family = af;
        auto handle = cast(socket_t) socket(af, type, protocol);
        if (handle == socket_t.init)
            throw new SocketOSException("Unable to create socket");
        setSock(handle);
    }

    /// ditto
    this(AddressFamily af, SocketType type)
    {
        /* A single protocol exists to support this socket type within the
         * protocol family, so the ProtocolType is assumed.
         */
        this(af, type, cast(ProtocolType) 0);         // Pseudo protocol number.
    }


    /// ditto
    this(AddressFamily af, SocketType type, scope const(char)[] protocolName) @trusted
    {
        protoent* proto;
        proto = getprotobyname(protocolName.tempCString());
        if (!proto)
            throw new SocketOSException("Unable to find the protocol");
        this(af, type, cast(ProtocolType) proto.p_proto);
    }


    /**
     * Create a blocking socket using the parameters from the specified
     * `AddressInfo` structure.
     */
    this(const scope AddressInfo info)
    {
        this(info.family, info.type, info.protocol);
    }

    /// Use an existing socket handle.
    this(socket_t sock, AddressFamily af) pure nothrow @nogc
    {
        assert(sock != socket_t.init);
        this.sock = sock;
        this._family = af;
    }


    ~this() nothrow @nogc
    {
        close();
    }


    /// Get underlying socket handle.
    @property socket_t handle() const pure nothrow @nogc
    {
        return sock;
    }

    /**
     * Releases the underlying socket handle from the Socket object. Once it
     * is released, you cannot use the Socket object's methods anymore. This
     * also means the Socket destructor will no longer close the socket - it
     * becomes your responsibility.
     *
     * To get the handle without releasing it, use the `handle` property.
     */
    @property socket_t release() pure nothrow @nogc
    {
        auto h = sock;
        this.sock = socket_t.init;
        return h;
    }

    /**
     * Get/set socket's blocking flag.
     *
     * When a socket is blocking, calls to receive(), accept(), and send()
     * will block and wait for data/action.
     * A non-blocking socket will immediately return instead of blocking.
     */
    @property bool blocking() @trusted const nothrow @nogc
    {
        version (Windows)
        {
            return _blocking;
        }
        else version (LinuxLike)
        {
            return !(fcntl(handle, F_GETFL, 0) & O_NONBLOCK);
        }
    }

    /// ditto
    @property void blocking(bool byes) @trusted
    {
        version (Windows)
        {
            uint num = !byes;
            if (_SOCKET_ERROR == ioctlsocket(sock, FIONBIO, &num))
                goto err;
            _blocking = byes;
        }
        else version (LinuxLike)
        {
            int x = fcntl(sock, F_GETFL, 0);
            if (-1 == x)
                goto err;
            if (byes)
                x &= ~O_NONBLOCK;
            else
                x |= O_NONBLOCK;
            if (-1 == fcntl(sock, F_SETFL, x))
                goto err;
        }
        return;         // Success.

 err:
        throw new SocketOSException("Unable to set socket blocking");
    }


    /// Get the socket's address family.
    @property AddressFamily addressFamily()
    {
        return _family;
    }

    /// Property that indicates if this is a valid, alive socket.
    @property bool isAlive() @trusted const
    {
        int type;
        socklen_t typesize = cast(socklen_t) type.sizeof;
        return !getsockopt(sock, SOL_SOCKET, SO_TYPE, cast(char*)&type, &typesize);
    }

    /**
     * Associate a local address with this socket.
     *
     * Params:
     *     addr = The $(LREF Address) to associate this socket with.
     *
     * Throws: $(LREF SocketOSException) when unable to bind the socket.
     */
    void bind(Address addr) @trusted
    {
        if (_SOCKET_ERROR == .bind(sock, addr.name, addr.nameLen))
            throw new SocketOSException("Unable to bind socket");
    }

    /**
     * Establish a connection. If the socket is blocking, connect waits for
     * the connection to be made. If the socket is nonblocking, connect
     * returns immediately and the connection attempt is still in progress.
     */
    void connect(Address to) @trusted
    {
        if (_SOCKET_ERROR == .connect(sock, to.name, to.nameLen))
        {
            int err;
            err = _lasterr();

            if (!blocking)
            {
                version (Windows)
                {
                    if (WSAEWOULDBLOCK == err)
                        return;
                }
                else version (LinuxLike)
                {
                    if (EINPROGRESS == err)
                        return;
                }
                else
                {
                    static assert(0);
                }
            }
            throw new SocketOSException("Unable to connect socket", err);
        }
    }

    /**
     * Listen for an incoming connection. `bind` must be called before you
     * can `listen`. The `backlog` is a request of how many pending
     * incoming connections are queued until `accept`ed.
     */
    void listen(int backlog) @trusted
    {
        if (_SOCKET_ERROR == .listen(sock, backlog))
            throw new SocketOSException("Unable to listen on socket");
    }

    /**
     * Called by `accept` when a new `Socket` must be created for a new
     * connection. To use a derived class, override this method and return an
     * instance of your class. The returned `Socket`'s handle must not be
     * set; `Socket` has a protected constructor `this()` to use in this
     * situation.
     *
     * Override to use a derived class.
     * The returned socket's handle must not be set.
     */
    protected Socket accepting() pure nothrow
    {
        return new Socket;
    }

    /**
     * Accept an incoming connection. If the socket is blocking, `accept`
     * waits for a connection request. Throws `SocketAcceptException` if
     * unable to _accept. See `accepting` for use with derived classes.
     */
    Socket accept() @trusted
    {
        auto newsock = cast(socket_t).accept(sock, null, null);
        if (socket_t.init == newsock)
            return null;

        Socket newSocket;
        try
        {
            newSocket = accepting();
            assert(newSocket.sock == socket_t.init);

            newSocket.setSock(newsock);
            version (Windows)
                newSocket._blocking = _blocking;                 //inherits blocking mode
            newSocket._family = _family;             //same family
        }
        catch (Throwable o)
        {
            _close(newsock);
            throw o;
        }

        return newSocket;
    }

    /// Disables sends and/or receives.
    void shutdown(SocketShutdown how) @trusted nothrow @nogc
    {
        .shutdown(sock, cast(int) how);
    }


    private static void _close(socket_t sock) @system nothrow @nogc
    {
        version (Windows)
        {
            .closesocket(sock);
        }
        else version (LinuxLike)
        {
            .close(sock);
        }
    }


    /**
     * Immediately drop any connections and release socket resources.
     * The `Socket` object is no longer usable after `close`.
     * Calling `shutdown` before `close` is recommended
     * for connection-oriented sockets.
     */
    void close() scope @trusted nothrow @nogc
    {
        _close(sock);
        sock = socket_t.init;
    }


    /**
     * Returns: The local machine's host name
     */
    static @property string hostName() @trusted     // getter
    {
        char[256] result;         // Host names are limited to 255 chars.
        if (_SOCKET_ERROR == .gethostname(result.ptr, result.length))
            throw new SocketOSException("Unable to obtain host name");
        return to!string(result.ptr);
    }

    /// Remote endpoint `Address`.
    @property Address remoteAddress() @trusted
    {
        Address addr = createAddress();
        socklen_t nameLen = addr.nameLen;
        if (_SOCKET_ERROR == .getpeername(sock, addr.name, &nameLen))
            throw new SocketOSException("Unable to obtain remote socket address");
        addr.setNameLen(nameLen);
        assert(addr.addressFamily == _family);
        return addr;
    }

    /// Local endpoint `Address`.
    @property Address localAddress() @trusted
    {
        Address addr = createAddress();
        socklen_t nameLen = addr.nameLen;
        if (_SOCKET_ERROR == .getsockname(sock, addr.name, &nameLen))
            throw new SocketOSException("Unable to obtain local socket address");
        addr.setNameLen(nameLen);
        assert(addr.addressFamily == _family);
        return addr;
    }

    /**
     * Send or receive error code. See `wouldHaveBlocked`,
     * `lastSocketError` and `Socket.getErrorText` for obtaining more
     * information about the error.
     */
    enum int ERROR = _SOCKET_ERROR;

    private static int capToInt(size_t size) nothrow @nogc
    {
        // Windows uses int instead of size_t for length arguments.
        // Luckily, the send/recv functions make no guarantee that
        // all the data is sent, so we use that to send at most
        // int.max bytes.
        return size > size_t(int.max) ? int.max : cast(int) size;
    }

    /**
     * Send data on the connection. If the socket is blocking and there is no
     * buffer space left, `send` waits.
     * Returns: The number of bytes actually sent, or `Socket.ERROR` on
     * failure.
     */
    ptrdiff_t send(scope const(void)[] buf, SocketFlags flags) @trusted
    {
        static if (is(typeof(MSG_NOSIGNAL)))
        {
            flags = cast(SocketFlags)(flags | MSG_NOSIGNAL);
        }
        version (Windows)
            auto sent = .send(sock, buf.ptr, capToInt(buf.length), cast(int) flags);
        else
            auto sent = .send(sock, buf.ptr, buf.length, cast(int) flags);
        return sent;
    }

    /// ditto
    ptrdiff_t send(scope const(void)[] buf)
    {
        return send(buf, SocketFlags.NONE);
    }

    /**
     * Send data to a specific destination Address. If the destination address is
     * not specified, a connection must have been made and that address is used.
     * If the socket is blocking and there is no buffer space left, `sendTo` waits.
     * Returns: The number of bytes actually sent, or `Socket.ERROR` on
     * failure.
     */
    ptrdiff_t sendTo(scope const(void)[] buf, SocketFlags flags, Address to) @trusted
    {
        static if (is(typeof(MSG_NOSIGNAL)))
        {
            flags = cast(SocketFlags)(flags | MSG_NOSIGNAL);
        }
        version (Windows)
            return .sendto(
                       sock, buf.ptr, capToInt(buf.length),
                       cast(int) flags, to.name, to.nameLen
                       );
        else
            return .sendto(sock, buf.ptr, buf.length, cast(int) flags, to.name, to.nameLen);
    }

    /// ditto
    ptrdiff_t sendTo(scope const(void)[] buf, Address to)
    {
        return sendTo(buf, SocketFlags.NONE, to);
    }


    //assumes you connect()ed
    /// ditto
    ptrdiff_t sendTo(scope const(void)[] buf, SocketFlags flags) @trusted
    {
        static if (is(typeof(MSG_NOSIGNAL)))
        {
            flags = cast(SocketFlags)(flags | MSG_NOSIGNAL);
        }
        version (Windows)
            return .sendto(sock, buf.ptr, capToInt(buf.length), cast(int) flags, null, 0);
        else
            return .sendto(sock, buf.ptr, buf.length, cast(int) flags, null, 0);
    }


    //assumes you connect()ed
    /// ditto
    ptrdiff_t sendTo(scope const(void)[] buf)
    {
        return sendTo(buf, SocketFlags.NONE);
    }


    /**
     * Receive data on the connection. If the socket is blocking, `receive`
     * waits until there is data to be received.
     * Returns: The number of bytes actually received, `0` if the remote side
     * has closed the connection, or `Socket.ERROR` on failure.
     */
    ptrdiff_t receive(scope void[] buf, SocketFlags flags) @trusted
    {
        version (Windows)         // Does not use size_t
        {
            return buf.length
                   ? .recv(sock, buf.ptr, capToInt(buf.length), cast(int) flags)
                   : 0;
        }
        else
        {
            return buf.length
                   ? .recv(sock, buf.ptr, buf.length, cast(int) flags)
                   : 0;
        }
    }

    /// ditto
    ptrdiff_t receive(scope void[] buf)
    {
        return receive(buf, SocketFlags.NONE);
    }

    /**
     * Receive data and get the remote endpoint `Address`.
     * If the socket is blocking, `receiveFrom` waits until there is data to
     * be received.
     * Returns: The number of bytes actually received, `0` if the remote side
     * has closed the connection, or `Socket.ERROR` on failure.
     */
    ptrdiff_t receiveFrom(scope void[] buf, SocketFlags flags, ref Address from) @trusted
    {
        if (!buf.length)         //return 0 and don't think the connection closed
            return 0;
        if (from is null || from.addressFamily != _family)
            from = createAddress();
        socklen_t nameLen = from.nameLen;
        version (Windows)
            auto read = .recvfrom(sock, buf.ptr, capToInt(buf.length), cast(int) flags, from.name, &nameLen);

        else
            auto read = .recvfrom(sock, buf.ptr, buf.length, cast(int) flags, from.name, &nameLen);

        if (read >= 0)
        {
            from.setNameLen(nameLen);
            assert(from.addressFamily == _family);
        }
        return read;
    }


    /// ditto
    ptrdiff_t receiveFrom(scope void[] buf, ref Address from)
    {
        return receiveFrom(buf, SocketFlags.NONE, from);
    }


    //assumes you connect()ed
    /// ditto
    ptrdiff_t receiveFrom(scope void[] buf, SocketFlags flags) @trusted
    {
        if (!buf.length)         //return 0 and don't think the connection closed
            return 0;
        version (Windows)
        {
            auto read = .recvfrom(sock, buf.ptr, capToInt(buf.length), cast(int) flags, null, null);
            // if (!read) //connection closed
            return read;
        }
        else
        {
            auto read = .recvfrom(sock, buf.ptr, buf.length, cast(int) flags, null, null);
            // if (!read) //connection closed
            return read;
        }
    }


    //assumes you connect()ed
    /// ditto
    ptrdiff_t receiveFrom(scope void[] buf)
    {
        return receiveFrom(buf, SocketFlags.NONE);
    }


    /**
     * Get a socket option.
     * Returns: The number of bytes written to `result`.
     * The length, in bytes, of the actual result - very different from getsockopt()
     */
    int getOption(SocketOptionLevel level, SocketOption option, scope void[] result) @trusted
    {
        socklen_t len = cast(socklen_t) result.length;
        if (_SOCKET_ERROR == .getsockopt(sock, cast(int) level, cast(int) option, result.ptr, &len))
            throw new SocketOSException("Unable to get socket option");
        return len;
    }


    /// Common case of getting integer and boolean options.
    int getOption(SocketOptionLevel level, SocketOption option, out int32_t result) @trusted
    {
        return getOption(level, option, (&result)[0 .. 1]);
    }


    /// Get the linger option.
    // int getOption(SocketOptionLevel level, SocketOption option, out Linger result) @trusted
    // {
    //     //return getOption(cast(SocketOptionLevel) SocketOptionLevel.SOCKET, SocketOption.LINGER, (&result)[0 .. 1]);
    //     return getOption(level, option, (&result.clinger)[0 .. 1]);
    // }

    /// Set a socket option.
    void setOption(SocketOptionLevel level, SocketOption option, scope void[] value) @trusted
    {
        if (_SOCKET_ERROR == .setsockopt(sock, cast(int) level,
                                        cast(int) option, value.ptr, cast(uint) value.length))
            throw new SocketOSException("Unable to set socket option");
    }


    /// Common case for setting integer and boolean options.
    void setOption(SocketOptionLevel level, SocketOption option, int32_t value) @trusted
    {
        setOption(level, option, (&value)[0 .. 1]);
    }


    /// Set the linger option.
    // void setOption(SocketOptionLevel level, SocketOption option, Linger value) @trusted
    // {
    //     //setOption(cast(SocketOptionLevel) SocketOptionLevel.SOCKET, SocketOption.LINGER, (&value)[0 .. 1]);
    //     setOption(level, option, (&value.clinger)[0 .. 1]);
    // }
    /**
     * Get a text description of this socket's error status, and clear the
     * socket's error status.
     */
    string getErrorText()
    {
        int32_t error;
        getOption(SocketOptionLevel.SOCKET, SocketOption.ERROR, error);
        return formatSocketError(error);
    }

    /**
     * Enables TCP keep-alive with the specified parameters.
     *
     * Params:
     *   time     = Number of seconds with no activity until the first
     *              keep-alive packet is sent.
     *   interval = Number of seconds between when successive keep-alive
     *              packets are sent if no acknowledgement is received.
     *
     * Throws: `SocketOSException` if setting the options fails, or
     * `SocketFeatureException` if setting keep-alive parameters is
     * unsupported on the current platform.
     */
    void setKeepAlive(int time, int interval) @trusted
    {
        version (Windows)
        {
            tcp_keepalive options;
            options.onoff = 1;
            options.keepalivetime = time * 1000;
            options.keepaliveinterval = interval * 1000;
            uint cbBytesReturned;
            enforce(WSAIoctl(sock, SIO_KEEPALIVE_VALS,
                             &options, options.sizeof,
                             null, 0,
                             &cbBytesReturned, null, null) == 0,
                    new SocketOSException("Error setting keep-alive"));
        }
        else
        static if (is(typeof(TCP_KEEPIDLE)) && is(typeof(TCP_KEEPINTVL)))
        {
            setOption(SocketOptionLevel.TCP, cast(SocketOption) TCP_KEEPIDLE, time);
            setOption(SocketOptionLevel.TCP, cast(SocketOption) TCP_KEEPINTVL, interval);
            setOption(SocketOptionLevel.SOCKET, SocketOption.KEEPALIVE, true);
        }
        else
            throw new SocketFeatureException("Setting keep-alive options " ~
                "is not supported on this platform");
    }

    // /// ditto
    // //maximum timeout
    static int select(SocketSet checkRead, SocketSet checkWrite, SocketSet checkError)
    {
        return select(checkRead, checkWrite, checkError, null);
    }

    /// Ditto
    static int select(SocketSet checkRead, SocketSet checkWrite, SocketSet checkError, TimeVal* timeout) @trusted
    in
    {
        //make sure none of the SocketSet's are the same object
        if (checkRead)
        {
            assert(checkRead !is checkWrite);
            assert(checkRead !is checkError);
        }
        if (checkWrite)
        {
            assert(checkWrite !is checkError);
        }
    }
    do
    {
        fd_set* fr, fw, fe;
        int n = 0;

        version (Windows)
        {
            // Windows has a problem with empty fd_set`s that aren't null.
            fr = checkRead  && checkRead.count  ? checkRead.toFd_set()  : null;
            fw = checkWrite && checkWrite.count ? checkWrite.toFd_set() : null;
            fe = checkError && checkError.count ? checkError.toFd_set() : null;
        }
        else
        {
            if (checkRead)
            {
                fr = checkRead.toFd_set();
                n = checkRead.selectn();
            }
            else
            {
                fr = null;
            }

            if (checkWrite)
            {
                fw = checkWrite.toFd_set();
                int _n;
                _n = checkWrite.selectn();
                if (_n > n)
                    n = _n;
            }
            else
            {
                fw = null;
            }

            if (checkError)
            {
                fe = checkError.toFd_set();
                int _n;
                _n = checkError.selectn();
                if (_n > n)
                    n = _n;
            }
            else
            {
                fe = null;
            }

            // Make sure the sets' capacity matches, to avoid select reading
            // out of bounds just because one set was bigger than another
            if (checkRead ) checkRead .setMinCapacity(n);
            if (checkWrite) checkWrite.setMinCapacity(n);
            if (checkError) checkError.setMinCapacity(n);
        }

        int result = .select(n, fr, fw, fe, &timeout.ctimeval);

        version (Windows)
        {
            if (_SOCKET_ERROR == result && WSAGetLastError() == WSAEINTR)
                return -1;
        }
        else version (LinuxLike)
        {
            if (_SOCKET_ERROR == result && errno == EINTR)
                return -1;
        }
        else
        {
            static assert(0);
        }

        if (_SOCKET_ERROR == result)
            throw new SocketOSException("Socket select error");

        return result;
    }


    /**
     * Can be overridden to support other addresses.
     * Returns: A new `Address` object for the current address family.
     */
    protected Address createAddress() pure nothrow
    {
        Address result;
        switch (_family)
        {
        static if (is(sockaddr_un))
        {
            case AddressFamily.UNIX:
                result = new UnixAddress;
                break;
        }

        case AddressFamily.INET:
            result = new InternetAddress;
            break;

        case AddressFamily.INET6:
            result = new Internet6Address;
            break;

        default:
            result = new UnknownAddress;
        }
        return result;
    }

}


/// Shortcut class for a TCP Socket.
class TcpSocket: Socket
{
    /// Constructs a blocking TCP Socket.
    this(AddressFamily family)
    {
        super(family, SocketType.STREAM, ProtocolType.TCP);
    }

    /// Constructs a blocking IPv4 TCP Socket.
    this()
    {
        this(AddressFamily.INET);
    }


    //shortcut
    /// Constructs a blocking TCP Socket and connects to the given `Address`.
    this(Address connectTo)
    {
        this(connectTo.addressFamily);
        connect(connectTo);
    }
}


/// Shortcut class for a UDP Socket.
class UdpSocket: Socket
{
    /// Constructs a blocking UDP Socket.
    this(AddressFamily family)
    {
        super(family, SocketType.DGRAM, ProtocolType.UDP);
    }


    /// Constructs a blocking IPv4 UDP Socket.
    this()
    {
        this(AddressFamily.INET);
    }
}



/**
 * Creates a pair of connected sockets.
 *
 * The two sockets are indistinguishable.
 *
 * Throws: `SocketException` if creation of the sockets fails.
 */
Socket[2] socketPair() @trusted
{
    version (LinuxLike)
    {
        int[2] socks;
        if (socketpair(AF_UNIX, SOCK_STREAM, 0, socks) == -1)
            throw new SocketOSException("Unable to create socket pair");

        Socket toSocket(size_t id)
        {
            auto s = new Socket;
            s.setSock(cast(socket_t) socks[id]);
            s._family = AddressFamily.UNIX;
            return s;
        }

        return [toSocket(0), toSocket(1)];
    }
    else version (Windows)
    {
        // We do not have socketpair() on Windows, just manually create a
        // pair of sockets connected over some localhost port.
        Socket[2] result;

        auto listener = new TcpSocket();
        listener.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
        listener.bind(new InternetAddress(INADDR_LOOPBACK, InternetAddress.PORT_ANY));
        auto addr = listener.localAddress;
        listener.listen(1);

        result[0] = new TcpSocket(addr);
        result[1] = listener.accept();

        listener.close();
        return result;
    }
    else
        static assert(false);
}

///
