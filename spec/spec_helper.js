require('coffee-script');
should_helper = require('should');
redis = require('redis');

Leaderboard = require('../lib/leaderboard');
TieRankingLeaderboard = require('../lib/tie_ranking_leaderboard');
CompetitionRankingLeaderboard = require('../lib/competition_ranking_leaderboard');
