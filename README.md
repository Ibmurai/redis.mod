redis.mod - A BlitzMax [Redis](http://www.redis.io/) client
===================================

Requirements
------------

 *  This client utilizes "The new unified request protocol", so it will only work with Redis >= 1.2.
 *  The "full" (see TODO) Redis 2.2.4 command set is available, but commands will only work with a Redis server supporting them (i.e OBJECT is only available from Redis 2.2.3+).

Building
--------

1. You should have a working [BlitzMax](http://blitzmax.com/Products/blitzmax.php) 1.42 installation.
2. Clone this project in `/path/to/blitzmax/mod/pub.mod/redis.mod`.
3. Build the module with `bmk makemods -h pub.redis` and `bmk makemods pub.redis` to get both the multithreaded and singlethreaded versions.

Usage
-----

 *  All Redis commands are called on a client instance by calling client.COMMAND_(). (See TODO for missing commands)

 *  The Redis commands all end with an underscore, to eliminate keyword clashes (i.e. SELECT) and distinguish Redis functionality from other functionality on the TRedisClient type.
 
 *  All commands return String.

Use it like this:

    Import Pub.Redis

    Local redis:TRedisClient = TRedisClient.Create()

    If redis.Open()
        Print redis.PING_()
        Print redis.INFO_()
        redis.ZADD_("someSet", 1, "one")
        redis.ZADD_("someSet", 2, "two")
        Print redis.ZRANGE_("someSet", 0, -1)
        Print redis.PING_()

        redis.Close()
    Else
        Print("Could not connect to Redis server at " + redis.host + ":" + redis.port)
    EndIf

HISTORY
-------

### v0.1a

 *  First version. Fully working implementation of the protocol.

TODO
----

1. Wrap the commands: SORT, ZINTERSTORE, ZUNIONSTORE.
2. Build an extensive testing application.
3. Implement a non blocking mode.
4. Look into delivering the more complex responses in a different way than just a string. Maybe.
