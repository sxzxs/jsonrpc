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