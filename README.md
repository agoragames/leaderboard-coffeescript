# leaderboard

Leaderboards backed by [Redis](http://redis.io) in CoffeeScript.

Builds off ideas proposed in http://blog.agoragames.com/2011/01/01/creating-high-score-tables-leaderboards-using-redis/.

## Installation

`npm install ???`

TBD: Figure out what to do here since there's already a leaderboard library on npmjs.org :(

Make sure your redis server is running! Redis configuration is outside the scope of this README, but
check out the [Redis documentation](http://redis.io/documentation).

## Usage

All methods take a callback as the final argument. The callback is non-optional for methods that return data.

### Creating a leaderboard

Create a new leaderboard or attach to an existing leaderboard named 'highscores':

```javascript
highscores = new Leaderboard('highscores')
```

### Ranking members in the leaderboard

Add members to your leaderboard using `rankMember`:

```javascript
for index in [1..50]
  highscores.rankMember("member_#{index}", index, "Optional member data for member #{index}", (reply) -> )
```

You can call `rankMember` with the same member and the leaderboard will be updated automatically.

Get some information about your leaderboard:

```javascript
highscores.totalMembers((numMembers) -> ...)

highscores.totalPages(Leaderboard.DEFAULT_PAGE_SIZE, (totalPages) -> ...)
```

Get some information about a specific member(s) in the leaderboard:

```javascript
highscores.scoreFor('member_5', (memberScore) -> ...)

highscores.rankFor('member_5', (memberRank) -> ...)
```

### Retrieving members from the leaderboard

Get page 1 in the leaderboard:

```javascript
highscores.leaders(1, {'with_member_data': false}, (leaders) -> ...)
```

Get an "Around Me" leaderboard page for a given member, which pulls members above and below the given member:

```javascript
highscores.aroundMe('member_25', {'with_member_data': false}, (leaders) -> ...)
```

Get rank and score for an arbitrary list of members (e.g. friends) from the leaderboard:

```javascript
highscores.rankedInList(['member_5', 'member_17', 'member_1'], {'with_member_data': false}, (leaders) -> ...)
```

Retrieve members from the leaderboard in a given score range:

```javascript
highscores.membersFromScoreRange(10, 15, {'with_member_data': false}, (leaders) -> ...)
```

Retrieve a single member from the leaderboard at a given position:

```javascript
highscores.memberAt(4, {'with_member_data': false}, (member) -> ...)
```

Retrieve a range of members from the leaderboard within a given rank range:

```javascript
highscores.membersFromRankRange(5, 9, {'with_member_data': false}, (leaders) -> ...)
```

### Conditionally rank a member in the leaderboard

You can pass a function to the `rankMemberIf` method to conditionally rank a member in the leaderboard. The function is passed the following 5 parameters:

* `member`: Member name.
* `currentScore`: Current score for the member in the leaderboard. This property is currently supplied when calling the `rankMemberIf` method.
* `score`: Member score.
* `memberData`: Optional member data.
* `options`: Leaderboard options, e.g. 'reverse': Value of reverse option

```javascript
highscoreCheck = (member, currentScore, score, memberData, leaderboardOptions) ->
  return true if !currentScore?
  return true if score > currentScore
  false

highscores.rankMemberIf(highscoreCheck, 'david', 1337, null, 'Optional member data', (reply) -> ...)
```

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

Copyright (c) 2012-2013 David Czarnecki. See LICENSE.txt for further details.
