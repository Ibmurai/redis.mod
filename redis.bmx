
SuperStrict

Module Pub.Redis

ModuleInfo "Version: 0.1"
ModuleInfo "Author: Jens Riisom Schultz"
ModuleInfo "License: BSD License"

Import BRL.SocketStream

Private

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

Public

Rem
bbdoc: A Redis client.
EndRem
Type TRedisClient

    Const NULL_STRING:String = "<~~-NULL-~~>"

    Field port:Int
    Field host:String
    Field stream:TSocketStream = Null

' ! --- Public Functions ---

    Rem
    bbdoc: Create a new connection to a redis server. The connection
    should be opened by calling Open() on the returned connection.
    EndRem
    Function Create:TRedisClient(host:String = "localhost", port:Int = 6379)
        Local conn:TRedisClient = New TRedisClient

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
                    Throw "Connection is open."
                Case False
                    Throw "Connection is closed."
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
            Local res:String = ""

            Select line[..1]
                Case "+", "-", ":"
                    res :+ line[1..]
                Case "$"
                    Local number:Int = line[1..].ToInt()
                    If number = -1 Then
                        res :+ NULL_STRING + "~r~n"
                    Else
                        'The buffer size is +3 because we need room for ~r~n~0
                        Local buff:Byte[] = New Byte[number + 3]
                        buff[number + 2] = 0
                        stream.Read(buff, number + 2)
                        res :+ String.FromCString(buff)
                    EndIf
                Case "*"
                    Local count:Int = line[1..].ToInt()

                    If count > 0 Then
                        For Local i:Int = 0 To count
                            line = stream.ReadLine()
                            Local number:Int = line[1..].ToInt()

                            If number = -1 Then
                                res :+ NULL_STRING + "~r~n"
                            ElseIf number > 0 Then
                                'The buffer size is +1 because we need room for ~0
                                Local buff:Byte[] = New Byte[number + 1]
                                buff[number] = 0
                                stream.Read(buff, number)
                                res :+ String.FromCString(buff).Trim() + "~r~n"
                            EndIf
                        Next
                        'Read the final ~r~n, but ditch it,
                        'because we added it manually above.
                        res :+ stream.ReadLine()
                    EndIf
                Default
                    res = "Unknown response type:~r~n" + line
            EndSelect

            Return res.Trim()
        EndIf
    EndMethod

    Rem
    bbdoc: Internally used method.
    Will block and read from the stream until the string sequence given
    is encountered. It will ignore the first character, when looking for
    the sequence, to ensure you read more than the marker itself.

    This was used for debugging. I have left it here, cause I may need it
    again :P

    Method _ReadUntil:String(seq:String)
        WriteStdout("_ReadUntil called.~r~n")

        Local buff:Byte[] = New Byte[256]
        Local offset:Byte = 0
        Local i:Int, start:Int
        Local seqFound:Int

        Repeat
            Try
                WriteStdout("   offset = " + offset + "~r~n")

                buff[offset] = stream.ReadByte()

                WriteStdout("   READ ~q" + Chr(buff[offset]) + "~q.~r~n")

                offset :+ 1
                If offset > seq.length Then
                    start = offset - seq.length
                    seqFound = True
                    For i = start To offset - 1
                        If Not (buff[i] = seq[i - start])
                            seqFound = False
                        EndIf
                    Next
                    If seqFound Then
                        buff[offset] = Asc("~0")

                        Local res:String = String.FromCString(buff)
                        WriteStdout("   RETURN ~q" + res + "~q~r~n")

                        Return res
                    EndIf
                EndIf
            Catch ex:TStreamReadException
                ' Do nothing / wait / repeat
            EndTry
        Forever
    EndMethod
    EndRem

EndType
