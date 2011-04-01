redis.mod - A BlitzMax [Redis](http://www.redis.io/) client
===================================

Requirements
------------

 *  This client utilizes "The new unified request protocol", so it will only work with Redis >= 1.2.

Building
--------

1. You should have a working [BlitzMax](http://blitzmax.com/Products/blitzmax.php) 1.41 installation.
2. You should have a working [Redis](http://www.redis.io/) server
3. Clone this project in `/path/to/blitzmax/mod/pub.mod/redis.mod`.
4. Build the module with `bmk makemods -h pub.redis` and `bmk makemods pub.redis` to get both the multithreaded and singlethreaded versions.

Usage
-----

The goal is to have code like this work:

    Import Pub.Redis
    
    Local redis:TRedisClient = TRedisClient.Create()
    
    redis.Open()
    
    Print redis.PING()
    Print redis.INFO()
    redis.ZADD("someSet", 1, "one")
    redis.ZADD("someSet", 2, "two")
    Print redis.ZRANGE("someSet", 0, -1)
    redis.Close()
    
But the commands have not been wrapped yet, so for now, this is what you do:

    Import Pub.Redis
    
    Local redis:TRedisClient = TRedisClient.Create()
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

TODO
----

1. Make the example work / get rid of the "Unknown response type:"-errors.
2. Wrap all the commands.
3. Look into delivering the more complex responses in a different way than just a string.
4. Build an extensive testing application.
5. Implement a non blocking mode.
