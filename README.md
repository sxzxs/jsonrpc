# JSON-RPC for AutoHotkey
this is a JSON-RPC library for AutoHotkey.

# AHK version
    AHK version: 2.0.14

## Usage
client
```ahk
#include <jsonrpc>

tClient := JsonRpcSocket("\\.\pipe\testPipe")
rtn := tClient.invokeRemoteMethod('getTime')
rtn.setCallBack((rtnData) => (MsgBox(rtnData.response.result)))

MsgBox(tClient.invokeRemoteMethodBlocking('getTime').result)

MsgBox(tClient.invokeRemoteMethodBlocking('add', 199, 299).result)
```

server
```ahk
Persistent
#include <jsonrpc>

server := JsonRpcSocketServer(, "\\.\pipe\testPipe")
server.addService(MyService())
class MyService
{
    add(a, b)
    {
        return a + b
    }
    getTime()
    {
        static index := 0
        index++
        rtn := '今天的时间是： ' A_Now ' ' index
        return rtn
    }
}

```
