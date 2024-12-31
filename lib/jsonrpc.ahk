#include "Socket.ahk"
#include "Promise.ahk"
#MaxThreads 255

JSONMESSAGE_INVALID := 1
JSONMESSAGE_REQUEST := 4
JSONMESSAGE_RESPONSE := 8
JSONMESSAGE_NOTIFICATION := 16
JSONMESSAGE_ERROR := 32

class JsonRpc
{
    static ErrorCode := {NoError: 0, 
                        ParseError:         -32700,     ;Invalid JSON was received by the server.
                                                        ;An error occurred on the server while parsing the JSON text.
                        InvalidRequest:     -32600,     ;The JSON sent is not a valid Request object.
                        MethodNotFound:     -32601,     ;The method does not exist / is not available.
                        InvalidParams:      -32602,     ;Invalid method parameter(s).
                        InternalError:      -32603,     ;Internal JSON-RPC error.
                        ServerErrorBase:    -32000,     ;Reserved for implementation-defined server-errors.
                        UserError:          -32099,     ;Anything after this is user defined
                        TimeoutError:       -32100} 
}

class JsonMessage
{
	static type := { Invalid: 1, Request: 4, Response: 8, Notification: 16, Error: 32 }
    static uniqueRequestCounter := 0
    __New() 
    {
        this.obj := {}
        this.type := JSONMESSAGE_INVALID
    }

    static createRequest(method, params*)
    {
        request := JsonMessage()
        request.obj.method := method
        request.obj.params := params
        JsonMessage.uniqueRequestCounter++
        request.obj.id :=  JsonMessage.uniqueRequestCounter
        return request
    }

    static createNotification()
    {

    }

    createResponse(result)
    {
        response := JsonMessage()
        if(this.obj.HasProp('id'))
        {
            response.obj.id := this.obj.id
        }
        response.obj.result := result
        response.type := JSONMESSAGE_RESPONSE
        return response
    }

    static createErrorResponse(code, message := '', data := {})
    {
        response := JsonMessage()
        error := {}
        error.code := code
        error.message := message
        error.data := data
        JsonMessage.type := JSONMESSAGE_ERROR
        response.error := error
    }

    createErrorResponse(code, message, data)
    {
        response := JsonMessage()
        error := {}
        error.code := code
        error.message := message
        error.data := data
        JsonMessage.type := JSONMESSAGE_ERROR
        if(this.obj.HasProp('id'))
        {
            response.obj.id := this.obj.id
        }
        response.error := error
    }

    toJson()
    {
        return JSON.stringify(this.obj)
    }

    initWithObject(message)
    {
        if(message.has('id'))
        {
            this.obj.id := message['id']
            if(message.has('result'))
            {
                this.obj.result := message['result']
                this.type := JSONMESSAGE_RESPONSE
            }
            else
            {
                if(message.has('method'))
                {
                    this.obj.method := message['method']
                    if(message.has('params'))
                    {
                        this.obj.params := message['params']
                    }
                    else
                    {
                        this.obj.params := []
                    }
                    this.type := JSONMESSAGE_REQUEST
                }
            }
        }
    }

    static fromJson(jsonStr)
    {
        jsonObj := JSON.parse(jsonStr)
        return this.fromObject(jsonObj)
    }

    static fromObject(message)
    {
        result := JsonMessage()
        result.initWithObject(message)
        return result
    }

    isValid()
    {
        return this.type != JSONMESSAGE_INVALID
    }

    params
    {
        get => this.obj.params
        set => this.obj.params := value
    }

    result
    {
        get => this.obj.result
        set => this.obj.result := value
    }

    id
    {
        get => this.obj.id
        set => this.obj.id := value
    }

    type
    {
        get => this.obj.type
        set => this.obj.type := Value
    }

    method
    {
        get => this.obj.method
        set => this.obj.method := value
    }
}

getSendTextLength(text, encoding := 'utf-8')
{
    return Buffer(StrPut(text, encoding) - (encoding = 'utf-16' || encoding = 'cp1200' ? 2 : 1)).Size
}

class JsonRpcSocketServer extends Socket.Server 
{
	static Prototype._recvbuf := 0
    dispatch(message)
    {
        ; check params
        method := message.method
        parame := message.params

        try
        {
            rtn := this.service.%method%(parame*)
            return response := message.createResponse(rtn)
        }
        catch
        {
            error := message.createErrorResponse(JsonRpc.ErrorCode.InvalidParams, "invalid params")
            return error
        }
    }

	onACCEPT(err) 
    {
		this.client := this.AcceptAsClient()
		this.client.onREAD := onread
		onread(socket, err) 
        {
            OutputDebug('onACCEPT')
            if err
            {
                OutputDebug('error: ' OSError(err).Message)
                return
            }
            if !buf := this._recvbuf 
            {
                if socket._recv(buf := Buffer(40, 0), 40, 2) > 0 && i := InStr(s := StrGet(buf, 'utf-8'), '`n')
                {
                    if RegExMatch(s, '^Content-Length:\s*(\d+)`r`n', &m)
                    {
                        buf := this._recvbuf := Buffer(m.Len + 2 + m[1]), buf.pos := 0, buf.skip := m.Len + 2
                    }
                    else {
                        OutputDebug('unknown line: ' (s := SubStr(s, 1, i)))
                        socket._recv(buf := Buffer(StrPut(s, 'utf-8') - 1), buf.Size)
                    }
                }
                return
            }
            s := socket._recv(buf.Ptr + buf.pos, buf.Size - buf.pos)
            OutputDebug(s)
            if s >= 0 
            {
                if (buf.pos += s) = buf.Size 
                {
                    this._recvbuf := 0
                    recvText := StrGet(buf.Ptr + buf.skip, buf.Size - buf.skip, 'utf-8')
                    try
                    {
                        jsObj := JSON.parse(recvText)
                    }
                    catch
                    {
                        return
                    }
                    request := JsonMessage.fromObject(JSON.parse(recvText))
                    switch(request.type)
                    {
                        case JSONMESSAGE_NOTIFICATION, JSONMESSAGE_REQUEST:
                            timer :=  ObjBindMethod(this, "handleData", socket, request)
                            SetTimer(timer, -1)
                        case JSONMESSAGE_RESPONSE:
                            ; do nothing
                        default:
                            error := request.createErrorResponse(JsonRpc.ErrorCode.InvalidRequest, "invalid request")
                            socket.SendText(JSON.stringify(error.obj))
                    }
                }
                return
            }
            else
            {
                err := Socket.GetLastError()
                OutputDebug('error: ' OSError(err).Message)
            }
		}
	}

    handleData(socket, request)
    {
        response := this.dispatch(request)
        responseStr := JSON.stringify(response.obj)
        socket.SendText('Content-Length: ' getSendTextLength(responseStr) '`r`n`r`n' responseStr)
    }

    addService(service)
    {
        this.service := service
    }
}


class JsonRpcServiceReply
{
    __New() 
    {
        this.request := JsonMessage()
        this.response := JsonMessage()
    }

    setCallBack(onResponse)
    {
        this.onResponse := onResponse
    }
}

class JsonRpcSocket
{
    __New(device, port?) 
    {
        this.device := JsonRpcSocket.ClientSocket(device, port?? unset)
        this.device.setSocket(this)
        this.replys := Map()
        this.currentResolve := ''
    }

    notify(message)
    {
        requestText := message.toJson()
        this.device.SendText('Content-Length: ' getSendTextLength(requestText) '`r`n`r`n' requestText)
    }

    sendMessage(message)
    {
        this.notify(message)
        reply := JsonRpcServiceReply()
        reply.request := message
        this.replys[message.id] := reply
        return reply
    }

    sendMessageBlockingSleep(message, timeout := 30000)
    {
        old := Critical(0)
        reply := this.sendMessage(message)
        start := A_TickCount
        loop
        {
            Sleep(-1)
            if(reply.response.isValid())
                break
        }until(A_TickCount - start > timeout)
        Critical(old)
    }

    sendMessageBlocking(message, timeout := 30000)
    {
        try
        {
            reply := JsonRpcServiceReply()
            pr := Promise((resolve, reject) => (reply := this.sendMessage(message), reply.resolve := resolve))
            pr.await2(timeout)
            return reply.response
        }
        catch
        {
            return JsonMessage.createErrorResponse(JsonRpc.ErrorCode.TimeoutError, "timeout error")
        }
    }

    invokeRemoteMethod(method, params*)
    {
        message := JsonMessage.createRequest(method, params*)
        reply := this.sendMessage(message)
        return reply
    }

    invokeRemoteMethodBlocking(method, params*)
    {
        message := JsonMessage.createRequest(method, params*)
        return  this.sendMessageBlocking(message)
    }

    class ClientSocket extends Socket.Client 
    {
	    static Prototype._recvbuf := 0
        onRead(err) 
        {
            if err
            {
                OutputDebug('error: ' OSError(err).Message)
                return
            }
            if !buf := this._recvbuf 
            {
                if this._recv(buf := Buffer(40, 0), 40, 2) > 0 && i := InStr(s := StrGet(buf, 'utf-8'), '`n')
                {
                    if RegExMatch(s, '^Content-Length:\s*(\d+)`r`n', &m)
                    {
                        buf := this._recvbuf := Buffer(m.Len + 2 + m[1]), buf.pos := 0, buf.skip := m.Len + 2
                    }
                    else 
                    {
                        OutputDebug('unknown line: ' (s := SubStr(s, 1, i)))
                        this._recv(buf := Buffer(StrPut(s, 'utf-8') - 1), buf.Size)
                    }
                }
                return
            }
            s := this._recv(buf.Ptr + buf.pos, buf.Size - buf.pos)
            if s >= 0 
            {
                if (buf.pos += s) = buf.Size 
                {
                    this._recvbuf := 0
                    recvtext := StrGet(buf.Ptr + buf.skip, buf.Size - buf.skip, 'utf-8')
                    recvJsonObj := JSON.parse(recvtext)
                    if(this.socket.replys.has(recvJsonObj['id']))
                    {
                        id := recvJsonObj['id']
                        this.socket.replys[id].response.type := JSONMESSAGE_RESPONSE
                        this.socket.replys[id].response.result := recvJsonObj['result']
                        this.socket.replys[id].response.id := recvJsonObj['id']

                        if(ObjHasOwnProp(this.socket.replys[id], 'resolve'))
                        {
                            (this.socket.replys[id].resolve)('recv response')
                        }
                        else if(ObjHasOwnProp(this.socket.replys[id], 'onResponse'))
                        {
                            (this.socket.replys[id].onResponse)(this.socket.replys[id])
                        }
                        this.socket.replys.delete(id)
                    }
                }
                return
            }
            else
            {
                err := Socket.GetLastError()
                OutputDebug('error: ' OSError(err).Message)
            }
        }

        setSocket(socket)
        {
            this.socket := socket
        }
    }
}