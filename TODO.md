Things I might want to add
===========================

* More control over refresh interval
* Attempt to stop spamming tweets when tickets appear/disappear
* Some kind of webpage to show the contents of the database
* History of all ticket appearances

The most important is #1 as if I have a 60s refresh interval it uses up twice as much bandwidth as 120s. But I want to have more control over the refresh interval when it goes into fast mode.

As an example, with a 2 min refresh interval:

* If new tix are found on the last X collections (say X = 3)
* Move to the faster refresh interval for the next Y collections (say Y = 10)
* Only if all Y collections returned 0 tickets do we go back to the slower interval