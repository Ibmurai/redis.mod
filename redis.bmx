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
    Takes the args array and sends it as a request to the Redis server.
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

' ! --- Redis Connection Methods ---

    Rem
    bbdoc: AUTH: Authenticate to the server.
    Returns a Status code reply.
    Documentation: http://www.redis.io/commands/auth
    EndRem
    Method AUTH_:String(password:String)
        Local args:String[] = ["AUTH", password]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: ECHO: Echo the given string.
    Returns a Bulk reply.
    Documentation: http://www.redis.io/commands/echo
    EndRem
    Method ECHO_:String(message:String)
        Local args:String[] = ["ECHO", message]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: PING: Ping the server.
    Returns a Status code reply.
    Documentation: http://www.redis.io/commands/ping
    EndRem
    Method PING_:String()
        Local args:String[] = ["PING"]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: QUIT: Close the connection.
    Returns a Status code reply.
    Documentation: http://www.redis.io/commands/quit
    EndRem
    Method QUIT_:String()
        Local args:String[] = ["QUIT"]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: SELECT: Change the selected database for the current connection.
    Returns a Status code reply.
    Documentation: http://www.redis.io/commands/select
    EndRem
    Method SELECT_:String(index:String)
        Local args:String[] = ["SELECT", index]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

' ! --- Redis Generic Methods ---

    Rem
    bbdoc: DEL: Delete a key.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/del
    EndRem
    Method DEL_:String(keys:String[])
        Local args:String[] = ["DEL"] + keys
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: EXISTS: Determine if a key exists.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/exists
    EndRem
    Method EXISTS_:String(key:String)
        Local args:String[] = ["EXISTS", key]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: EXPIRE: Set a key's time to live in seconds.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/expire
    EndRem
    Method EXPIRE_:String(key:String, seconds:Int)
        Local args:String[] = ["EXPIRE", key, String.FromInt(seconds)]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: EXPIREAT: Set the expiration for a key as a UNIX timestamp.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/expireat
    EndRem
    Method EXPIREAT_:String(key:String, timestamp:Int)
        Local args:String[] = ["EXPIREAT", key, String.FromInt(timestamp)]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: KEYS: Find all keys matching the given pattern.
    Returns a Multi-bulk reply.
    Documentation: http://www.redis.io/commands/keys
    EndRem
    Method KEYS_:String(pattern:String)
        Local args:String[] = ["KEYS", pattern]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: MOVE: Move a key to another database.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/move
    EndRem
    Method MOVE_:String(key:String, db:String)
        Local args:String[] = ["MOVE", key, db]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: OBJECT: Inspect the internals of Redis objects.
    Returns an Integer reply or a bulk reply, depending on the subcommand.
    Documentation: http://redis.io/commands/object
    EndRem
    Method OBJECT_:String(subcommand:String, arguments:String[])
        Local args:String[] = ["OBJECT", subcommand] + arguments
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: PERSIST: Remove the expiration from a key.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/persist
    EndRem
    Method PERSIST_:String(key:String)
        Local args:String[] = ["PERSIST", key]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: RANDOMKEY: Return a random key from the keyspace.
    Returns a Bulk reply.
    Documentation: http://www.redis.io/commands/randomkey
    EndRem
    Method RANDOMKEY_:String()
        Local args:String[] = ["RANDOMKEY"]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: RENAME: Rename a key.
    Returns a Status code reply.
    Documentation: http://www.redis.io/commands/rename
    EndRem
    Method RENAME_:String(key:String, newkey:String)
        Local args:String[] = ["RENAME", key, newkey]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: RENAMENX: Rename a key, only if the new key does not exist.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/renamenx
    EndRem
    Method RENAMENX_:String(key:String, newkey:String)
        Local args:String[] = ["RENAMENX", key, newkey]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: SORT: Sort the elements in a list, set or sorted set.
    Returns a Multi-bulk reply.
    Documentation: http://www.redis.io/commands/sort
    EndRem
    Rem TODO
    Method SORT_:String(key:String, [BY pattern]:String, [LIMIT offset count]:String, [GET pattern [GET pattern ...]]:String, [ASC|DESC]:String, [ALPHA]:String, [STORE destination]:String)
        Local args:String[] = ["SORT", key, [BY pattern], [LIMIT offset count], [GET pattern [GET pattern ...]], [ASC|DESC], [ALPHA], [STORE destination]]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod
    EndRem

    Rem
    bbdoc: TTL: Get the time to live for a key.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/ttl
    EndRem
    Method TTL_:String(key:String)
        Local args:String[] = ["TTL", key]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: TYPE: Determine the type stored at key.
    Returns a Status code reply.
    Documentation: http://www.redis.io/commands/type
    EndRem
    Method TYPE_:String(key:String)
        Local args:String[] = ["TYPE", key]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

' ! --- Redis Hash Methods ---

    Rem
    bbdoc: HDEL: Delete a hash field.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/hdel
    EndRem
    Method HDEL_:String(key:String, _field:String)
        Local args:String[] = ["HDEL", key, _field]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: HEXISTS: Determine if a hash field exists.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/hexists
    EndRem
    Method HEXISTS_:String(key:String, _field:String)
        Local args:String[] = ["HEXISTS", key, _field]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: HGET: Get the value of a hash field.
    Returns a Bulk reply.
    Documentation: http://www.redis.io/commands/hget
    EndRem
    Method HGET_:String(key:String, _field:String)
        Local args:String[] = ["HGET", key, _field]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: HGETALL: Get all the fields and values in a hash.
    Returns a Multi-bulk reply.
    Documentation: http://www.redis.io/commands/hgetall
    EndRem
    Method HGETALL_:String(key:String)
        Local args:String[] = ["HGETALL", key]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: HINCRBY: Increment the integer value of a hash field by the given number.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/hincrby
    EndRem
    Method HINCRBY_:String(key:String, _field:String, increment:Int)
        Local args:String[] = ["HINCRBY", key, _field, String.FromInt(increment)]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: HKEYS: Get all the fields in a hash.
    Returns a Multi-bulk reply.
    Documentation: http://www.redis.io/commands/hkeys
    EndRem
    Method HKEYS_:String(key:String)
        Local args:String[] = ["HKEYS", key]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: HLEN: Get the number of fields in a hash.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/hlen
    EndRem
    Method HLEN_:String(key:String)
        Local args:String[] = ["HLEN", key]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: HMGET: Get the values of all the given hash fields.
    Returns a Multi-bulk reply.
    Documentation: http://www.redis.io/commands/hmget
    EndRem
    Method HMGET_:String(key:String, fields:String[])
        Local args:String[] = ["HMGET", key] + fields
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: HMSET: Set multiple hash fields to multiple values.
    Returns a Status code reply.
    Documentation: http://www.redis.io/commands/hmset
    EndRem
    Rem TODO
    Method HMSET_:String(key:String, field value [field value ...]:String)
        Local args:String[] = ["HMSET", key, field value [field value ...]]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod
    EndRem

    Rem
    bbdoc: HSET: Set the string value of a hash field.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/hset
    EndRem
    Method HSET_:String(key:String, _field:String, value:String)
        Local args:String[] = ["HSET", key, _field, value]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: HSETNX: Set the value of a hash field, only if the field does not exist.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/hsetnx
    EndRem
    Method HSETNX_:String(key:String, _field:String, value:String)
        Local args:String[] = ["HSETNX", key, _field, value]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: HVALS: Get all the values in a hash.
    Returns a Multi-bulk reply.
    Documentation: http://www.redis.io/commands/hvals
    EndRem
    Method HVALS_:String(key:String)
        Local args:String[] = ["HVALS", key]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

' ! --- Redis List Methods ---

    Rem
    bbdoc: BLPOP: Remove and get the first element in a list, or block until one is available.
    Returns a Multi-bulk reply.
    Documentation: http://www.redis.io/commands/blpop
    EndRem
    Method BLPOP_:String(keys:String[], timeout:Int)
        Local args:String[] = ["BLPOP"] + keys + [String.FromInt(timeout)]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: BRPOP: Remove and get the last element in a list, or block until one is available.
    Returns a Multi-bulk reply.
    Documentation: http://www.redis.io/commands/brpop
    EndRem
    Method BRPOP_:String(keys:String[], timeout:Int)
        Local args:String[] = ["BRPOP"] + keys + [String.FromInt(timeout)]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: BRPOPLPUSH: Pop a value from a list, push it to another list and return it; or block until one is available.
    Returns a Bulk reply.
    Documentation: http://www.redis.io/commands/brpoplpush
    EndRem
    Method BRPOPLPUSH_:String(source:String, destination:String, timeout:Int)
        Local args:String[] = ["BRPOPLPUSH", source, destination, String.FromInt(timeout)]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: LINDEX: Get an element from a list by its index.
    Returns a Bulk reply.
    Documentation: http://www.redis.io/commands/lindex
    EndRem
    Method LINDEX_:String(key:String, index:String)
        Local args:String[] = ["LINDEX", key, index]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: LINSERT: Insert an element before or after another element in a list.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/linsert
    EndRem
    Rem TODO
    Method LINSERT_:String(key:String, BEFORE|AFTER:String, pivot:String, value:String)
        Local args:String[] = ["LINSERT", key, BEFORE|AFTER, pivot, value]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod
    EndRem

    Rem
    bbdoc: LLEN: Get the length of a list.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/llen
    EndRem
    Method LLEN_:String(key:String)
        Local args:String[] = ["LLEN", key]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: LPOP: Remove and get the first element in a list.
    Returns a Bulk reply.
    Documentation: http://www.redis.io/commands/lpop
    EndRem
    Method LPOP_:String(key:String)
        Local args:String[] = ["LPOP", key]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: LPUSH: Prepend a value to a list.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/lpush
    EndRem
    Method LPUSH_:String(key:String, value:String)
        Local args:String[] = ["LPUSH", key, value]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: LPUSHX: Prepend a value to a list, only if the list exists.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/lpushx
    EndRem
    Method LPUSHX_:String(key:String, value:String)
        Local args:String[] = ["LPUSHX", key, value]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: LRANGE: Get a range of elements from a list.
    Returns a Multi-bulk reply.
    Documentation: http://www.redis.io/commands/lrange
    EndRem
    Method LRANGE_:String(key:String, start:Int, stop:Int)
        Local args:String[] = ["LRANGE", key, String.FromInt(start), String.FromInt(stop)]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: LREM: Remove elements from a list.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/lrem
    EndRem
    Method LREM_:String(key:String, count:Int, value:String)
        Local args:String[] = ["LREM", key, String.FromInt(count), value]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: LSET: Set the value of an element in a list by its index.
    Returns a Status code reply.
    Documentation: http://www.redis.io/commands/lset
    EndRem
    Method LSET_:String(key:String, index:Int, value:String)
        Local args:String[] = ["LSET", key, String.FromInt(index), value]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: LTRIM: Trim a list to the specified range.
    Returns a Status code reply.
    Documentation: http://www.redis.io/commands/ltrim
    EndRem
    Method LTRIM_:String(key:String, start:Int, stop:Int)
        Local args:String[] = ["LTRIM", key, String.FromInt(start), String.FromInt(stop)]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: RPOP: Remove and get the last element in a list.
    Returns a Bulk reply.
    Documentation: http://www.redis.io/commands/rpop
    EndRem
    Method RPOP_:String(key:String)
        Local args:String[] = ["RPOP", key]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: RPOPLPUSH: Remove the last element in a list, append it to another list and return it.
    Returns a Bulk reply.
    Documentation: http://www.redis.io/commands/rpoplpush
    EndRem
    Method RPOPLPUSH_:String(source:String, destination:String)
        Local args:String[] = ["RPOPLPUSH", source, destination]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: RPUSH: Append a value to a list.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/rpush
    EndRem
    Method RPUSH_:String(key:String, value:String)
        Local args:String[] = ["RPUSH", key, value]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: RPUSHX: Append a value to a list, only if the list exists.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/rpushx
    EndRem
    Method RPUSHX_:String(key:String, value:String)
        Local args:String[] = ["RPUSHX", key, value]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

' ! --- Redis Pubsub Methods ---

    Rem
    bbdoc: PSUBSCRIBE: Listen for messages published to channels matching the given patterns.
    Documentation: http://www.redis.io/commands/psubscribe
    EndRem
    Method PSUBSCRIBE_:String(patterns:String[])
        Local args:String[] = ["PSUBSCRIBE"] + patterns
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: PUBLISH: Post a message to a channel.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/publish
    EndRem
    Method PUBLISH_:String(channel:String, message:String)
        Local args:String[] = ["PUBLISH", channel, message]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: PUNSUBSCRIBE: Stop listening for messages posted to channels matching the given patterns.
    Documentation: http://www.redis.io/commands/punsubscribe
    EndRem
    Method PUNSUBSCRIBE_:String(patterns:String[])
        Local args:String[] = ["PUNSUBSCRIBE"] + patterns
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: SUBSCRIBE: Listen for messages published to the given channels.
    Documentation: http://www.redis.io/commands/subscribe
    EndRem
    Method SUBSCRIBE_:String(channels:String[])
        Local args:String[] = ["SUBSCRIBE"] + channels
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: UNSUBSCRIBE: Stop listening for messages posted to the given channels.
    Documentation: http://www.redis.io/commands/unsubscribe
    EndRem
    Method UNSUBSCRIBE_:String(channels:String[])
        Local args:String[] = ["UNSUBSCRIBE"] + channels
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

' ! --- Redis Server Methods ---

    Rem
    bbdoc: BGREWRITEAOF: Asynchronously rewrite the append-only file.
    Returns a Status code reply.
    Documentation: http://www.redis.io/commands/bgrewriteaof
    EndRem
    Method BGREWRITEAOF_:String()
        Local args:String[] = ["BGREWRITEAOF"]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: BGSAVE: Asynchronously save the dataset to disk.
    Returns a Status code reply.
    Documentation: http://www.redis.io/commands/bgsave
    EndRem
    Method BGSAVE_:String()
        Local args:String[] = ["BGSAVE"]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: CONFIG GET: Get the value of a configuration parameter.
    Documentation: http://www.redis.io/commands/config-get
    EndRem
    Method CONFIG_GET_:String(parameter:String)
        Local args:String[] = ["CONFIG GET", parameter]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: CONFIG RESETSTAT: Reset the stats returned by INFO.
    Returns a Status code reply.
    Documentation: http://www.redis.io/commands/config-resetstat
    EndRem
    Method CONFIG_RESETSTAT_:String()
        Local args:String[] = ["CONFIG RESETSTAT"]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: CONFIG SET: Set a configuration parameter to the given value.
    Documentation: http://www.redis.io/commands/config-set
    EndRem
    Method CONFIG_SET_:String(parameter:String, value:String)
        Local args:String[] = ["CONFIG SET", parameter, value]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: DBSIZE: Return the number of keys in the selected database.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/dbsize
    EndRem
    Method DBSIZE_:String()
        Local args:String[] = ["DBSIZE"]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: DEBUG OBJECT: Get debugging information about a key.
    Documentation: http://www.redis.io/commands/debug-object
    EndRem
    Method DEBUG_OBJECT_:String(key:String)
        Local args:String[] = ["DEBUG OBJECT", key]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: DEBUG SEGFAULT: Make the server crash.
    Documentation: http://www.redis.io/commands/debug-segfault
    EndRem
    Method DEBUG_SEGFAULT_:String()
        Local args:String[] = ["DEBUG SEGFAULT"]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: FLUSHALL: Remove all keys from all databases.
    Returns a Status code reply.
    Documentation: http://www.redis.io/commands/flushall
    EndRem
    Method FLUSHALL_:String()
        Local args:String[] = ["FLUSHALL"]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: FLUSHDB: Remove all keys from the current database.
    Returns a Status code reply.
    Documentation: http://www.redis.io/commands/flushdb
    EndRem
    Method FLUSHDB_:String()
        Local args:String[] = ["FLUSHDB"]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: INFO: Get information and statistics about the server.
    Returns a Bulk reply.
    Documentation: http://www.redis.io/commands/info
    EndRem
    Method INFO_:String()
        Local args:String[] = ["INFO"]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: LASTSAVE: Get the UNIX time stamp of the last successful save to disk.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/lastsave
    EndRem
    Method LASTSAVE_:String()
        Local args:String[] = ["LASTSAVE"]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: MONITOR: Listen for all requests received by the server in real time.
    Documentation: http://www.redis.io/commands/monitor
    EndRem
    Method MONITOR_:String()
        Local args:String[] = ["MONITOR"]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: SAVE: Synchronously save the dataset to disk.
    Documentation: http://www.redis.io/commands/save
    EndRem
    Method SAVE_:String()
        Local args:String[] = ["SAVE"]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: SHUTDOWN: Synchronously save the dataset to disk and then shut down the server.
    Returns a Status code reply.
    Documentation: http://www.redis.io/commands/shutdown
    EndRem
    Method SHUTDOWN_:String()
        Local args:String[] = ["SHUTDOWN"]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: SLAVEOF: Make the server a slave of another instance, or promote it as master.
    Returns a Status code reply.
    Documentation: http://www.redis.io/commands/slaveof
    EndRem
    Method SLAVEOF_:String(host:String, port:String)
        Local args:String[] = ["SLAVEOF", host, port]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: SYNC: Internal command used for replication.
    Documentation: http://www.redis.io/commands/sync
    EndRem
    Method SYNC_:String()
        Local args:String[] = ["SYNC"]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

' ! --- Redis Set Methods ---

    Rem
    bbdoc: SADD: Add a member to a set.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/sadd
    EndRem
    Method SADD_:String(key:String, member:String)
        Local args:String[] = ["SADD", key, member]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: SCARD: Get the number of members in a set.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/scard
    EndRem
    Method SCARD_:String(key:String)
        Local args:String[] = ["SCARD", key]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: SDIFF: Subtract multiple sets.
    Returns a Multi-bulk reply.
    Documentation: http://www.redis.io/commands/sdiff
    EndRem
    Method SDIFF_:String(keys:String[])
        Local args:String[] = ["SDIFF"] + keys
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: SDIFFSTORE: Subtract multiple sets and store the resulting set in a key.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/sdiffstore
    EndRem
    Method SDIFFSTORE_:String(destination:String, keys:String[])
        Local args:String[] = ["SDIFFSTORE", destination] + keys
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: SINTER: Intersect multiple sets.
    Returns a Multi-bulk reply.
    Documentation: http://www.redis.io/commands/sinter
    EndRem
    Method SINTER_:String(keys:String[])
        Local args:String[] = ["SINTER"] + keys
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: SINTERSTORE: Intersect multiple sets and store the resulting set in a key.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/sinterstore
    EndRem
    Method SINTERSTORE_:String(destination:String, keys:String[])
        Local args:String[] = ["SINTERSTORE", destination] + keys
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: SISMEMBER: Determine if a given value is a member of a set.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/sismember
    EndRem
    Method SISMEMBER_:String(key:String, member:String)
        Local args:String[] = ["SISMEMBER", key, member]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: SMEMBERS: Get all the members in a set.
    Returns a Multi-bulk reply.
    Documentation: http://www.redis.io/commands/smembers
    EndRem
    Method SMEMBERS_:String(key:String)
        Local args:String[] = ["SMEMBERS", key]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: SMOVE: Move a member from one set to another.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/smove
    EndRem
    Method SMOVE_:String(source:String, destination:String, member:String)
        Local args:String[] = ["SMOVE", source, destination, member]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: SPOP: Remove and return a random member from a set.
    Returns a Bulk reply.
    Documentation: http://www.redis.io/commands/spop
    EndRem
    Method SPOP_:String(key:String)
        Local args:String[] = ["SPOP", key]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: SRANDMEMBER: Get a random member from a set.
    Returns a Bulk reply.
    Documentation: http://www.redis.io/commands/srandmember
    EndRem
    Method SRANDMEMBER_:String(key:String)
        Local args:String[] = ["SRANDMEMBER", key]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: SREM: Remove a member from a set.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/srem
    EndRem
    Method SREM_:String(key:String, member:String)
        Local args:String[] = ["SREM", key, member]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: SUNION: Add multiple sets.
    Returns a Multi-bulk reply.
    Documentation: http://www.redis.io/commands/sunion
    EndRem
    Method SUNION_:String(keys:String[])
        Local args:String[] = ["SUNION"] + keys
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: SUNIONSTORE: Add multiple sets and store the resulting set in a key.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/sunionstore
    EndRem
    Method SUNIONSTORE_:String(destination:String, keys:String[])
        Local args:String[] = ["SUNIONSTORE", destination] + keys
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

' ! --- Redis Sorted Set Methods ---

    Rem
    bbdoc: ZADD: Add a member to a sorted set, or update its score if it already exists.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/zadd
    EndRem
    Method ZADD_:String(key:String, score:Double, member:String)
        Local args:String[] = ["ZADD", key, String.FromDouble(score), member]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: ZCARD: Get the number of members in a sorted set.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/zcard
    EndRem
    Method ZCARD_:String(key:String)
        Local args:String[] = ["ZCARD", key]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: ZCOUNT: Count the members in a sorted set with scores within the given values.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/zcount
    EndRem
    Method ZCOUNT_:String(key:String, min_:Double, max_:Double)
        Local args:String[] = ["ZCOUNT", key, String.FromDouble(min_), String.FromDouble(max_)]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: ZINCRBY: Increment the score of a member in a sorted set.
    Returns a Bulk reply.
    Documentation: http://www.redis.io/commands/zincrby
    EndRem
    Method ZINCRBY_:String(key:String, increment:Double, member:String)
        Local args:String[] = ["ZINCRBY", key, String.FromDouble(increment), member]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: ZINTERSTORE: Intersect multiple sorted sets and store the resulting sorted set in a new key.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/zinterstore
    EndRem
    Rem TODO
    Method ZINTERSTORE_:String(destination:String, numkeys:String, key [key ...]:String, [WEIGHTS weight [weight ...]]:String, [AGGREGATE SUM|MIN|MAX]:String)
        Local args:String[] = ["ZINTERSTORE", destination, numkeys, key [key ...], [WEIGHTS weight [weight ...]], [AGGREGATE SUM|MIN|MAX]]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod
    EndRem

    Rem
    bbdoc: ZRANGE: Return a range of members in a sorted set, by index.
    Returns a Multi-bulk reply.
    Documentation: http://www.redis.io/commands/zrange
    EndRem
    Method ZRANGE_:String(key:String, start:Int, stop:Int, WITHSCORES:Int)
        Local args:String[] = ["ZRANGE", key, String.FromInt(start), String.FromInt(stop)]
        If WITHSCORES Then
            args :+ ["WITHSCORES"]
        EndIf
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: ZRANGEBYSCORE: Return a range of members in a sorted set, by score.
    Returns a Multi-bulk reply.
    Documentation: http://www.redis.io/commands/zrangebyscore
    EndRem
    Rem TODO
    Method ZRANGEBYSCORE_:String(key:String, min:String, max:String, [WITHSCORES]:String, [LIMIT offset count]:String)
        Local args:String[] = ["ZRANGEBYSCORE", key, min, max, [WITHSCORES], [LIMIT offset count]]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod
    EndRem

    Rem
    bbdoc: ZRANK: Determine the index of a member in a sorted set.
    Documentation: http://www.redis.io/commands/zrank
    EndRem
    Method ZRANK_:String(key:String, member:String)
        Local args:String[] = ["ZRANK", key, member]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: ZREM: Remove a member from a sorted set.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/zrem
    EndRem
    Method ZREM_:String(key:String, member:String)
        Local args:String[] = ["ZREM", key, member]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: ZREMRANGEBYRANK: Remove all members in a sorted set within the given indexes.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/zremrangebyrank
    EndRem
    Method ZREMRANGEBYRANK_:String(key:String, start:Int, stop:Int)
        Local args:String[] = ["ZREMRANGEBYRANK", key, String.FromInt(start), String.FromInt(stop)]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: ZREMRANGEBYSCORE: Remove all members in a sorted set within the given scores.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/zremrangebyscore
    EndRem
    Method ZREMRANGEBYSCORE_:String(key:String, min_:Double, max_:Double)
        Local args:String[] = ["ZREMRANGEBYSCORE", key, String.FromDouble(min_), String.FromDouble(max_)]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: ZREVRANGE: Return a range of members in a sorted set, by index, with scores ordered from high to low.
    Returns a Multi-bulk reply.
    Documentation: http://www.redis.io/commands/zrevrange
    EndRem
    Method ZREVRANGE_:String(key:String, start:Int, stop:Int, WITHSCORES:Int)
        Local args:String[] = ["ZREVRANGE", key, String.FromInt(start), String.FromInt(stop)]
        If WITHSCORES Then
            args :+ ["WITHSCORES"]
        EndIf
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: ZREVRANGEBYSCORE: Return a range of members in a sorted set, by score, with scores ordered from high to low.
    Returns a Multi-bulk reply.
    Documentation: http://www.redis.io/commands/zrevrangebyscore
    EndRem
    Rem TODO
    Method ZREVRANGEBYSCORE_:String(key:String, max:String, min:String, [WITHSCORES]:String, [LIMIT offset count]:String)
        Local args:String[] = ["ZREVRANGEBYSCORE", key, max, min, [WITHSCORES], [LIMIT offset count]]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod
    EndRem

    Rem
    bbdoc: ZREVRANK: Determine the index of a member in a sorted set, with scores ordered from high to low.
    Documentation: http://www.redis.io/commands/zrevrank
    EndRem
    Method ZREVRANK_:String(key:String, member:String)
        Local args:String[] = ["ZREVRANK", key, member]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: ZSCORE: Get the score associated with the given member in a sorted set.
    Returns a Bulk reply.
    Documentation: http://www.redis.io/commands/zscore
    EndRem
    Method ZSCORE_:String(key:String, member:String)
        Local args:String[] = ["ZSCORE", key, member]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: ZUNIONSTORE: Add multiple sorted sets and store the resulting sorted set in a new key.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/zunionstore
    EndRem
    Rem TODO
    Method ZUNIONSTORE_:String(destination:String, numkeys:String, key [key ...]:String, [WEIGHTS weight [weight ...]]:String, [AGGREGATE SUM|MIN|MAX]:String)
        Local args:String[] = ["ZUNIONSTORE", destination, numkeys, key [key ...], [WEIGHTS weight [weight ...]], [AGGREGATE SUM|MIN|MAX]]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod
    EndRem

' ! --- Redis String Methods ---

    Rem
    bbdoc: APPEND: Append a value to a key.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/append
    EndRem
    Method APPEND_:String(key:String, value:String)
        Local args:String[] = ["APPEND", key, value]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: DECR: Decrement the integer value of a key by one.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/decr
    EndRem
    Method DECR_:String(key:String)
        Local args:String[] = ["DECR", key]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: DECRBY: Decrement the integer value of a key by the given number.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/decrby
    EndRem
    Method DECRBY_:String(key:String, decrement:Int)
        Local args:String[] = ["DECRBY", key, String.FromInt(decrement)]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: GET: Get the value of a key.
    Returns a Bulk reply.
    Documentation: http://www.redis.io/commands/get
    EndRem
    Method GET_:String(key:String)
        Local args:String[] = ["GET", key]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: GETBIT: Returns the bit value at offset in the string value stored at key.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/getbit
    EndRem
    Method GETBIT_:String(key:String, offset:Int)
        Local args:String[] = ["GETBIT", key, String.FromInt(offset)]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: GETRANGE: Get a substring of the string stored at a key.
    Returns a Bulk reply.
    Documentation: http://www.redis.io/commands/getrange
    EndRem
    Method GETRANGE_:String(key:String, start:Int, end_:Int)
        Local args:String[] = ["GETRANGE", key, String.FromInt(start), String.FromInt(end_)]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: GETSET: Set the string value of a key and return its old value.
    Returns a Bulk reply.
    Documentation: http://www.redis.io/commands/getset
    EndRem
    Method GETSET_:String(key:String, value:String)
        Local args:String[] = ["GETSET", key, value]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: INCR: Increment the integer value of a key by one.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/incr
    EndRem
    Method INCR_:String(key:String)
        Local args:String[] = ["INCR", key]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: INCRBY: Increment the integer value of a key by the given number.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/incrby
    EndRem
    Method INCRBY_:String(key:String, increment:Int)
        Local args:String[] = ["INCRBY", key, String.FromInt(increment)]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: MGET: Get the values of all the given keys.
    Returns a Multi-bulk reply.
    Documentation: http://www.redis.io/commands/mget
    EndRem
    Method MGET_:String(keys:String[])
        Local args:String[] = ["MGET"] + keys
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: MSET: Set multiple keys to multiple values.
    Returns a Status code reply.
    Documentation: http://www.redis.io/commands/mset
    EndRem
    Rem TODO
    Method MSET_:String(key value [key value ...]:String)
        Local args:String[] = ["MSET", key value [key value ...]]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod
    EndRem

    Rem
    bbdoc: MSETNX: Set multiple keys to multiple values, only if none of the keys exist.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/msetnx
    EndRem
    Rem TODO
    Method MSETNX_:String(key value [key value ...]:String)
        Local args:String[] = ["MSETNX", key value [key value ...]]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod
    EndRem

    Rem
    bbdoc: SET: Set the string value of a key.
    Returns a Status code reply.
    Documentation: http://www.redis.io/commands/set
    EndRem
    Method SET_:String(key:String, value:String)
        Local args:String[] = ["SET", key, value]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: SETBIT: Sets or clears the bit at offset in the string value stored at key.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/setbit
    EndRem
    Method SETBIT_:String(key:String, offset:Int, value:Int)
        Local args:String[] = ["SETBIT", key, String.FromInt(offset), String.FromInt(value)]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: SETEX: Set the value and expiration of a key.
    Returns a Status code reply.
    Documentation: http://www.redis.io/commands/setex
    EndRem
    Method SETEX_:String(key:String, seconds:Int, value:String)
        Local args:String[] = ["SETEX", key, String.FromInt(seconds), value]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: SETNX: Set the value of a key, only if the key does not exist.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/setnx
    EndRem
    Method SETNX_:String(key:String, value:String)
        Local args:String[] = ["SETNX", key, value]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: SETRANGE: Overwrite part of a string at key starting at the specified offset.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/setrange
    EndRem
    Method SETRANGE_:String(key:String, offset:Int, value:String)
        Local args:String[] = ["SETRANGE", key, String.FromInt(offset), value]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: STRLEN: Get the length of the value stored in a key.
    Returns an Integer reply.
    Documentation: http://www.redis.io/commands/strlen
    EndRem
    Method STRLEN_:String(key:String)
        Local args:String[] = ["STRLEN", key]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

' ! --- Redis Transactions Methods ---

    Rem
    bbdoc: DISCARD: Discard all commands issued after MULTI.
    Returns a Status code reply.
    Documentation: http://www.redis.io/commands/discard
    EndRem
    Method DISCARD_:String()
        Local args:String[] = ["DISCARD"]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: EXEC: Execute all commands issued after MULTI.
    Returns a Multi-bulk reply.
    Documentation: http://www.redis.io/commands/exec
    EndRem
    Method EXEC_:String()
        Local args:String[] = ["EXEC"]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: MULTI: Mark the start of a transaction block.
    Returns a Status code reply.
    Documentation: http://www.redis.io/commands/multi
    EndRem
    Method MULTI_:String()
        Local args:String[] = ["MULTI"]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: UNWATCH: Forget about all watched keys.
    Returns a Status code reply.
    Documentation: http://www.redis.io/commands/unwatch
    EndRem
    Method UNWATCH_:String()
        Local args:String[] = ["UNWATCH"]
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

    Rem
    bbdoc: WATCH: Watch the given keys to determine execution of the MULTI/EXEC block.
    Returns a Status code reply.
    Documentation: http://www.redis.io/commands/watch
    EndRem
    Method WATCH_:String(keys:String[])
        Local args:String[] = ["WATCH"] + keys
        _SendRequest(args)
        Return _RecieveData()
    EndMethod

EndType
