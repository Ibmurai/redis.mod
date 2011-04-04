SuperStrict

Import Pub.Redis

Local redis:TRedisClient = TRedisClient.Create()

If redis.Open()
    Print redis.PING_()
    Print redis.INFO_()
    redis.ZADD_("someSet", 1, "one")
    redis.ZADD_("someSet", 2, "two")

    'ZRANGE is not yet implemented:    
    redis._SendRequest(["ZRANGE", "someSet", "0", "-1"])
    Print redis._RecieveData()

    Print redis.PING_()

    redis.Close()
Else
    Print("Could not connect to Redis server at " + redis.host + ":" + redis.port)
EndIf
