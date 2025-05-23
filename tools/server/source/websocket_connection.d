module websocket_connection;
import hip.api.net.server;
import hip.api.net.utils;
import std.stdio;
import core.sync.mutex;
import handy_httpd;
import hipengine_commands;

struct Connection
{
	uint id;
    WebSocketConnection socket;
}
public __gshared Connection*[] connections;

class HipremeEngineWebSocketServer: WebSocketMessageHandler
{
    // ctx.server.stop(); // Calling stop will gracefully shutdown the server.
    this()
    {
        wsMutex = new shared Mutex;
    }

    private uint wsID;

    override void onConnectionEstablished(WebSocketConnection conn)
    {
        // synchronized(wsMutex)
        {
            Connection* c;
            if(freeIdsList.length)
            {
                uint last = freeIdsList[$-1];
                freeIdsList = freeIdsList[0..$-1];
                c = connections[last];
                c.socket = conn;
                writeln("Socket ID ", NetID.start + c.id, " reacquired");
            }
            else
            {
                connections~= c = new Connection(id, conn);
                wsID = id++;
            }
            uint data = NetID.start + c.id;
            writeln("Socket ID ", data, " connected. Returning its ID.");
            conn.sendBinaryMessage(toBytes(data));
        }
    }

    override void onTextMessage(WebSocketTextMessage msg)
    {
        import std.stdio;
        import std.algorithm.searching;

        string text = msg.payload; //Irrelevant here

        // infoF!"Got TEXT: %s"(msg.payload);
    }

    static bool sendBinaryToSocket(uint toSocketID, ubyte[] data)
    {
        if(toSocketID >= connections.length)
        {
            writeln("toSocketID [", toSocketID, "] is out of range");
            return false;
        }

        connections[toSocketID].socket.sendBinaryMessage(data);
        return true;
    }

    /**
     * Specification:
     * 4 bytes is the from socket ID
     * 4 bytes is the to socket ID
     *
     * Remaining bytes are the data frame
     *
     * Params:
     *   msg =
     */
    override void onBinaryMessage(WebSocketBinaryMessage msg)
    {
        import std.stdio;

        uint fromSocketID = *cast(uint*)msg.payload[0..4] - NetID.start;
        uint toSocketID = *cast(uint*)msg.payload[4..8];

        ubyte[] data = fromNetworkBytes(msg.payload[8..$])[NetHeader.sizeof..$];

        switch(toSocketID)
        {
            case NetID.server:

                ubyte command = *cast(ubyte*)data.ptr;
                writeln("Received command ID [", command, "] from connection ", fromSocketID, " Buffer is ", data);
                switch(command)
                {
                    case MarkedNetReservedTypes.connect:
                        //Just pong it back to say it has connected.
                        sendBinaryToSocket(fromSocketID, getNetworkFormattedData(MarkedNetReservedTypes.connect));
                        break;
                    case MarkedNetReservedTypes.get_connected_clients:
                        auto response = getNetworkFormattedData(getConnectedClients(fromSocketID), MarkedNetReservedTypes.get_connected_clients);
                        sendBinaryToSocket(fromSocketID, response);
                        break;
                    case MarkedNetReservedTypes.client_connect:
                        uint targetID = *cast(uint*)(data.ptr+ubyte.sizeof); //After the command, the targetID
                        sendBinaryToSocket(targetID - NetID.start, getNetworkFormattedData(ConnectToClientResponse(fromSocketID), MarkedNetReservedTypes.client_connect));
                        break;
                    default:

                        writeln("Invalid Command Received. Buffer: ", data);
                        break;
                }
                break;
            case NetID.broadcast:
                writeln(fromSocketID, " is broadcasting!");
                foreach(c; connections)
                {
                    if(c.id != fromSocketID)
                        c.socket.sendBinaryMessage(data);
                }
                break;
            default:
                toSocketID-= NetID.start;
                if(connections.length <= toSocketID)
                    writeln("Socket tried sending data to invalid socket ID ", toSocketID + NetID.start);
                else
                    connections[toSocketID].socket.sendBinaryMessage(data);
                break;

        }
        // writeln("Socket ", fromSocketID, " is sending ", data.length, " bytes to socket ", toSocketID);

    }

    override void onCloseMessage(WebSocketCloseMessage msg)
    {
        import std.algorithm.searching;
        import std.conv:to;
        synchronized
        {
            ptrdiff_t index = countUntil!((Connection* c) => c.socket == msg.conn)(connections);
            if(index != -1)
            {
                writeln("Socket ", NetID.start + connections[index].id, " closed");
                connections[index].socket = null;
                freeIdsList~= index.to!uint;
            }
        }
    }
}

private __gshared uint id;

private __gshared uint[] freeIdsList;
private shared Mutex wsMutex;