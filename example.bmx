SuperStrict

Import Pub.Redis

Local redis:TRedisConnection = TRedisConnection.Create()
Local request:String[]

If redis.Open()
    request = ["PING"]
    redis._SendRequest(request)
    Print(redis._RecieveData())
    
    request = ["INFO"]
    redis._SendRequest(request)
    Print(redis._RecieveData())
    
    request = ["ZADD", "someSet", "1", "one"]
    redis._SendRequest(request)
    
    request = ["ZADD", "someSet", "2", "two"]
    redis._SendRequest(request)
    
    request = ["ZRANGE", "someSet", "0", "-1"]
    redis._SendRequest(request)
    Print(redis._RecieveData())
    
    redis.Close()
Else
    Print("Could not connect to Redis server at " + redis.host + ":" + redis.port)
EndIf
