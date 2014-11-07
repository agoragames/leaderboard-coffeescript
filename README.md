# leaderboard

Leaderboards backed by [Redis](http://redis.io) in JavaScript.

Builds off ideas proposed in http://www.agoragames.com/blog/2011/01/01/creating-high-score-tables-leaderboards-using-redis/.

## Installation

`npm install agoragames-leaderboard`

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
highscores.leaders(1, {'withMemberData': false}, (leaders) -> ...)
```

Get an "Around Me" leaderboard page for a given member, which pulls members above and below the given member:

```javascript
highscores.aroundMe('member_25', {'withMemberData': false}, (leaders) -> ...)
```

Get rank and score for an arbitrary list of members (e.g. friends) from the leaderboard:

```javascript
highscores.rankedInList(['member_5', 'member_17', 'member_1'], {'withMemberData': false}, (leaders) -> ...)
```

Retrieve members from the leaderboard in a given score range:

```javascript
highscores.membersFromScoreRange(10, 15, {'withMemberData': false}, (leaders) -> ...)
```

Retrieve a single member from the leaderboard at a given position:

```javascript
highscores.memberAt(4, {'withMemberData': false}, (member) -> ...)
```

Retrieve a range of members from the leaderboard within a given rank range:

```javascript
highscores.membersFromRankRange(5, 9, {'withMemberData': false}, (leaders) -> ...)
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

#### Optional member data notes

If you use optional member data, the use of the `removeMembersInScoreRange` or `removeMembersOutsideRank` methods
will leave data around in the member data hash. This is because the internal Redis method, `zremrangebyscore`,
only returns the number of items removed. It does not return the members that it removed.

#### Leaderboard request options

You can pass various options to the calls `leaders`, `allLeaders`, `aroundMe`, `membersFromScoreRange`, `membersFromRankRange` and `rankedInList`. Valid options are:

* `withMemberData` - `true` or `false` to return the optional member data.
* `pageSize` - An integer value to change the page size for that call.
* `membersOnly` - `true` or `false` to return only the members without their score and rank.
* `sortBy` - Valid values for `sortBy` are `score` and `rank`.

### Ranking a member across multiple leaderboards

```ruby
highscores.rankMemberAcross(['highscores', 'more_highscores'], 'david', 50000, { 'member_name': 'david' }, (reply) -> ...)
```

### Alternate leaderboard types

The leaderboard library offers 3 styles of ranking. This is only an issue for members with the same score in a leaderboard.

Default: The `Leaderboard` class uses the default Redis sorted set ordering, whereby different members having the same score are ordered lexicographically. As per the Redis documentation on Redis sorted sets, "The lexicographic ordering used is binary, it compares strings as array of bytes."

Tie ranking: The `TieRankingLeaderboard` subclass of `Leaderboard` allows you to define a leaderboard where members with the same score are given the same rank. For example, members in a leaderboard with the associated scores would have the ranks of:

```
| member     | score | rank |
-----------------------------
| member_1   | 50    | 1    |
| member_2   | 50    | 1    |
| member_3   | 30    | 2    |
| member_4   | 30    | 2    |
| member_5   | 10    | 3    |
```

The `TieRankingLeaderboard` accepts one additional option, `tiesNamespace` (default: ties), when initializing a new instance of this class. Please note that in its current implementation, the `TieRankingLeaderboard` class uses an additional sorted set to rank the scores, so please keep this in mind when you are doing any capacity planning for Redis with respect to memory usage.

Competition ranking: The `CompetitionRankingLeaderboard` subclass of `Leaderboard` allows you to define a leaderboard where members with the same score will have the same rank, and then a gap is left in the ranking numbers. For example, members in a leaderboard with the associated scores would have the ranks of:

```
| member     | score | rank |
-----------------------------
| member_1   | 50    | 1    |
| member_2   | 50    | 1    |
| member_3   | 30    | 3    |
| member_4   | 30    | 3    |
| member_5   | 10    | 5    |
```

## Performance Metrics

You can view [performance metrics](https://github.com/agoragames/leaderboard#performance-metrics) for the
leaderboard library at the original Ruby library's page.

## Ports

The following ports have been made of the [leaderboard gem](https://github.com/agoragames/leaderboard).

Officially supported:

* JavaScript: https://github.com/agoragames/leaderboard-coffeescript
* Python: https://github.com/agoragames/leaderboard-python
* Ruby: https://github.com/agoragames/leaderboard

Unofficially supported (they need some feature parity love):

* Java: https://github.com/agoragames/java-leaderboard
* PHP: https://github.com/agoragames/php-leaderboard
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

Copyright (c) 2012-2014 David Czarnecki. See LICENSE.txt for further details.
