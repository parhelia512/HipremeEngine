///TODO: Use port from serve.d
const _reloadSocket = new WebSocket("$WEBSOCKET_SERVER$");

_reloadSocket.addEventListener("open", (event) =>
{
    console.warn("Hipreme Engine auto-reload socket started.");
    const __updateMsg = 0xff;
    const updateLoop = setInterval(() => 
    {
        _reloadSocket.send(__updateMsg);
    }, 50);

    _reloadSocket.addEventListener("close", (event) =>
    {
        console.warn("Exited reload server connection.");
        clearInterval(updateLoop);
    });
});


_reloadSocket.addEventListener("message", (event) =>
{
    const serverMsg = String(event.data);
    switch(serverMsg)
    {
        case "reload":
        {
            __shouldReloadGame = true;
            break;  
        } 
        case "close": _reloadSocket.close(0); break;
        default: console.warn("Unknown message from server received: ", serverMsg); break;
    }
});


let __shouldReloadGame = false;
function __reloadGame()
{
    __shouldReloadGame = false;
    druntimeAbortHook();
    WasmUtils.cleanup();
    __loadGame();
}