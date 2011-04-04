redis.mod - A BlitzMax [Redis](http://www.redis.io/) client
===================================

Requirements
------------

 *  This client utilizes "The new unified request protocol", so it will only work with Redis >= 1.2.

Building
--------

1. You should have a working [BlitzMax](http://blitzmax.com/Products/blitzmax.php) 1.42 installation.
2. Clone this project in `/path/to/blitzmax/mod/pub.mod/redis.mod`.
3. Build the module with `bmk makemods -h pub.redis` and `bmk makemods pub.redis` to get both the multithreaded and singlethreaded versions.

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

TODO
----

1. Wrap all the commands.
2. Look into delivering the more complex responses in a different way than just a string.
3. Build an extensive testing application.
4. Implement a non blocking mode.

