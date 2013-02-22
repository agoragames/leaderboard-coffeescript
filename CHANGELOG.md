# CHANGELOG

## 1.0.0 (2013-02-22)

* Version 1.0.0!
* Fixed a data leak in `expireLeaderboard` and `expireLeaderboardAt` to also set expiration on the member data hash.

## 0.2.0

* Ensure the passed callback function is triggered when operations fail or are otherwise unable to complete. Pull request [#4](https://github.com/agoragames/leaderboard-coffeescript/pull/4)
* Fix for fetching the rank for the top member. Pull request [#2](https://github.com/agoragames/leaderboard-coffeescript/pull/2)
* Thanks to [David Wagner](https://github.com/mnem) for the above pull requests.

## 0.0.1

* Initial implementation
