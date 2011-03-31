
SuperStrict

Module Pub.Redis

ModuleInfo "Version: 0.1"
ModuleInfo "Author: Jens Riisom Schultz"
ModuleInfo "License: BSD License"

Import BRL.SocketStream

Rem
bbdoc: Returns param1 XOR param2.
EndRem
Function Xor:Int(param1:Int, param2:Int)
    Return (param1 And Not param2) Or (Not param1 And param2)
EndFunction

Rem
bbdoc: Returns "True" or "False"
EndRem
Function BooleanToString:String(param:Int)
    If param Then
        Return "True"
    Else
        Return "False"
    EndIf
EndFunction

Rem
bbdoc: A connection to a redis server.
EndRem
Type TRedisConnection

    Field port:Int
    Field host:String
    Field stream:TSocketStream = Null

' ! --- Public Functions ---

    Rem
    bbdoc: Create a new connection to a redis server. The connection
    should be opened by calling Open() on the returned connection.
    EndRem
    Function Create:TRedisConnection(host:String = "localhost", port:Int = 6379)
        Local conn:TRedisConnection = New TRedisConnection

        conn.port = port
        conn.host = host

        Return conn
    EndFunction

' ! --- Public Methods ---

    Rem
    bbdoc: Open the connection. Returns True on success and false on failure.
    Throws an exception if the connection is already open.
    EndRem
    Method Open:Int()
        If _EnsureClosed()
            stream = TSocketStream.CreateClient(host, port)
            Return IsOpen()
        EndIf
    EndMethod

    Rem
    bbdoc: Close the connection.
    EndRem
    Method Close()
        If _EnsureOpen()
            stream.Close()
            stream = Null
        EndIf
    EndMethod

    Rem
    bbdoc: Check if the connection is open.
    EndRem
    Method IsOpen:Int()
        Return stream <> Null
    EndMethod

    Rem
    bbdoc: Get the connection as a debug friendly string.
    EndRem
    Method ToString:String()
        Local res:String = ""

        res :+ "TRedisConnection {~r~n"
        res :+ "    host     : " + host                      + "~r~n"
        res :+ "    port     : " + port                      + "~r~n"
        res :+ "    IsOpen() : " + BooleanToString(IsOpen()) + "~r~n"
        res :+ "}"

        Return res
    EndMethod

' ! --- "Private" Methods ---

    Rem
    bbdoc: Internally used method.
    Throws an exception if the connection is not open.
    Returns true if the connection is open.
    EndRem
    Method _EnsureOpen:Int(invert:Int = False)
        Local isOpen:Int = IsOpen()

        If Xor(invert, isOpen) Then
            Return True
        Else
            Select isOpen
                Case True
                    Throw "Connection is already open."
                Case False
                    Throw "Connection is already closed."
            EndSelect
        EndIf
    EndMethod

    Rem
    bbdoc: Internally used method.
    Throws an exception if the connection is not closed.
    Returns true if the connection is open.
    EndRem
    Method _EnsureClosed:Int()
        Return _EnsureOpen(True)
    EndMethod

    Rem
    bbdoc: Internally used method.
    Takes the args array and sends it to
    EndRem
    Method _SendRequest(args:String[])
        If _EnsureOpen() Then
            Local requestString:String = ""

            requestString :+ "*" + args.length + "~r~n"

            For Local param:String = EachIn args
                requestString :+ "$" + param.length + "~r~n"
                requestString :+ param + "~r~n"
            Next

            stream.WriteLine(requestString.Trim())
        EndIf
    EndMethod

    Rem
    bbdoc: Internally used method.
    Recieve data as a string. The returned strings are trimmed,
    so there will never be a CRLF at the end.
    EndRem
    Method _RecieveData:String()
        If _EnsureOpen() Then
            Local line:String = stream.ReadLine()
            Local res:String

            Select line[..1]
                Case "+", "-", ":"
                    res = line[1..]
                Case "$"
                    Local number:Int = line[1..].ToInt()
                    If number = -1 Then
                        res = Null
                    Else
                        Local buff:Byte[] = New Byte[number]
                        stream.Read(buff, number)
                        res = String.FromCString(buff).Trim()
                    EndIf
                Case "*"
                    Local count:Int = line[1..].ToInt()
                    For Local i:Int = 0 To count
                        line = stream.ReadLine()
                        Local number:Int = line[1..].ToInt()

                        Local buff:Byte[] = New Byte[number]
                        stream.Read(buff, number)
                        res :+ String.FromCString(buff)
                    Next
                Default
                    res = "Unknown response type:~r~n" + line
            EndSelect

            Return res
        EndIf
    EndMethod

EndType

