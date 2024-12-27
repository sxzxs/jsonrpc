#include <jsonrpc>

tClient := JsonRpcSocket("\\.\pipe\testPipe")
rtn := tClient.invokeRemoteMethod('getTime')
rtn.setCallBack((rtnData) => (MsgBox(rtnData.response.result)))

MsgBox(tClient.invokeRemoteMethodBlocking('getTime').result)

MsgBox(tClient.invokeRemoteMethodBlocking('add', 199, 299).result)