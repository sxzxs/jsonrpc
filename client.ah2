Persistent
#include <jsonrpc>

;tClient := JsonRpcSocket("\\.\pipe\testPipe")
tClient := JsonRpcSocket("127.0.0.1", 5554)
loop(10)
{
    rtn := tClient.invokeRemoteMethod('getTime')
    rtn.setCallBack((rtnData) => (MsgBox(rtnData.response.result)))
}
Sleep(1000)

MsgBox(tClient.invokeRemoteMethodBlocking('add', 199, 299).result)