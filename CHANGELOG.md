# CHANGELOG

## 1.7.0 ()

* Fix `page_size` option for `aroundMe` call
* Added `TieRankingLeaderboard` and `CompetitionRankingLeaderboard` classes

## 1.6.0 (2014-02-15)

*  Allow for customization of member_data namespace [#12](https://github.com/agoragames/leaderboard-coffeescript/pull/12)

## 1.5.0 (2014-01-24)

* Allow for custom keys to be set for customizing the data returned from calls like leaders or aroundMe [#11](https://github.com/agoragames/leaderboard-coffeescript/pull/11)

## 1.4.0 (2013-11-12)

* Added `scoreForPercentile` method to be able to calculate the score for a given percentile value in the leaderboard.

## 1.3.0 (2013-07-17)

* Added `rankMemberAcross` method to be able to rank a member across multiple leaderboards at once.
* Fixed bug in `rankedInListIn` method that would not correctly use the `leaderboardName` argument.

## 1.2.0 (2013-05-31)

* Added `removeMembersOutsideRank` method to remove members from the leaderboard outside a given rank.

## 1.1.0 (2013-05-15)

* Added `members_only` option for various leaderboard requests.

## 1.0.0 (2013-02-22)

* Version 1.0.0!
* Fixed a data leak in `expireLeaderboard` and `expireLeaderboardAt` to also set expiration on the member data hash.

## 0.2.0

* Ensure the passed callback function is triggered when operations fail or are otherwise unable to complete. Pull request [#4](https://github.com/agoragames/leaderboard-coffeescript/pull/4)
* Fix for fetching the rank for the top member. Pull request [#2](https://github.com/agoragames/leaderboard-coffeescript/pull/2)
* Thanks to [David Wagner](https://github.com/mnem) for the above pull requests.

## 0.0.1

* Initial implementation
