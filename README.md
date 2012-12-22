# leaderboard

Leaderboards backed by [Redis](http://redis.io) in CoffeeScript.

Builds off ideas proposed in http://blog.agoragames.com/2011/01/01/creating-high-score-tables-leaderboards-using-redis/.

## Installation

`npm install ???`

TBD: Figure out what to do here since there's already a leaderboard library on npmjs.org :(

Make sure your redis server is running! Redis configuration is outside the scope of this README, but
check out the [Redis documentation](http://redis.io/documentation).

## Usage

### Creating a leaderboard

Create a new leaderboard or attach to an existing leaderboard named 'highscores':

```javascript
highscores = new Leaderboard('highscores')
```

### Ranking members in the leaderboard


### Retrieving members from the leaderboard


### Conditionally rank a member in the leaderboard


## Performance Metrics

You can view [performance metrics](https://github.com/agoragames/leaderboard#performance-metrics) for the 
leaderboard library at the original Ruby library's page.

## Ports

The following ports have been made of the [leaderboard gem](https://github.com/agoragames/leaderboard).

* Java: https://github.com/agoragames/java-leaderboard
* PHP: https://github.com/agoragames/php-leaderboard
* Python: https://github.com/agoragames/leaderboard-python
* Scala: https://github.com/agoragames/scala-leaderboard

## Contributing to leaderboard

* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it
* Fork the project
* Start a feature/bugfix branch
* Commit and push until you are happy with your contribution
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Makefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

## Copyright

Copyright (c) 2012 David Czarnecki. See LICENSE.txt for further details.
