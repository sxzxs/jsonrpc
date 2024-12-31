Persistent
#include <jsonrpc>


;server := JsonRpcSocketServer(, "\\.\pipe\testPipe")
server := JsonRpcSocketServer(5554, "127.0.0.1")
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
        Sleep(5000)
        return rtn
    }
}