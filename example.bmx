SuperStrict

Import Pub.Redis

Local redis:TRedisClient = TRedisClient.Create()
Local request:String[]

If redis.Open()
    request = ["PING"]
    Print("Sending: " + " ".Join(request))
    redis._SendRequest(request)
    Print("Recieved: " + redis._RecieveData())

    request = ["INFO"]
    Print("Sending: " + " ".Join(request))
    redis._SendRequest(request)
    Print("Recieved: " + redis._RecieveData())

    request = ["ZADD", "someSet", "1", "one"]
    Print("Sending: " + " ".Join(request))
    redis._SendRequest(request)
    Print("Recieved: " + redis._RecieveData())

    request = ["ZADD", "someSet", "2", "two"]
    Print("Sending: " + " ".Join(request))
    redis._SendRequest(request)
    Print("Recieved: " + redis._RecieveData())

    request = ["ZRANGE", "someSet", "0", "-1"]
    Print("Sending: " + " ".Join(request))
    redis._SendRequest(request)
    Print("Recieved: " + redis._RecieveData())

    request = ["PING"]
    Print("Sending: " + " ".Join(request))
    redis._SendRequest(request)
    Print("Recieved: " + redis._RecieveData())

    redis.Close()
Else
    Print("Could not connect to Redis server at " + redis.host + ":" + redis.port)
EndIf
