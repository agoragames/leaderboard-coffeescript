# CHANGELOG

## master

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
