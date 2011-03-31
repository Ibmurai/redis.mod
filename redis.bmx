
Module Pub.Redis

ModuleInfo "Version: 0.1"
ModuleInfo "Author: Jens Riisom Schultz"
ModuleInfo "License: BSD License"

Import BRL.SocketStream

Rem
bbdoc: Returns param1 XOR param2.
EndRem
Function Xor(param1:Int, param2:Int)
    Return (param1 And Not param2) Or (Not param1 And param2)
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
    bbdoc: Open the connection.
    EndRem
    Method Open:Int()
        If _EnsureClosed()
            stream = TSocketStream.CreateClient(host, port)
        EndIf
    EndMethod

    Rem
    bbdoc: Close the connection.
    EndRem
    Method Close:Int()
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

' ! --- "Private" Methods ---

    Rem
    bbdoc: Internally used method.
    Throws an exception if the connection is not open.
    Returns true if the connection is open.
    EndRem
    Method _EnsureOpen:Int(invert:Int = False)
        Local isOpen:Int = IsOpen()

        If Xor(invert, isOpen) Then
            Select isOpen
                Case True
                    Throw "Connection is already open."
                Case False
                    Throw "Connection is already closed."
            EndSelect
        Else
            Return True
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

EndType

