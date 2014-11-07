Leaderboard = require './leaderboard'

class CompetitionRankingLeaderboard extends Leaderboard
  ###
  # Retrieve the rank for a member in the named leaderboard.
  #
  # @param leaderboardName [String] Name of the leaderboard.
  # @param member [String] Member name.
  # @param callback Callback for result of call.
  #
  # @return the rank for a member in the leaderboard.
  ###
  rankForIn: (leaderboardName, member, callback) ->
    @redisConnection.zscore(leaderboardName, member, (err, score) =>
      if @reverse
        @redisConnection.zcount(leaderboardName, '-inf', "(#{score}", (err, memberScore) =>
          callback(memberScore + 1))
      else
        @redisConnection.zcount(leaderboardName, "(#{score}", '+inf', (err, memberScore) =>
          callback(memberScore + 1))
    )

  ###
  # Retrieve the score and rank for a member in the named leaderboard.
  #
  # @param leaderboardName [String]Name of the leaderboard.
  # @param member [String] Member name.
  # @param callback Callback for result of call.
  #
  # @return the score and rank for a member in the named leaderboard as a Hash.
  ###
  scoreAndRankForIn: (leaderboardName, member, callback) ->
    @redisConnection.zscore(leaderboardName, member, (err, memberScore) =>
      transaction = @redisConnection.multi()
      transaction.zscore(leaderboardName, member)
      if @reverse
        transaction.zrank(leaderboardName, memberScore)
      else
        transaction.zrevrank(leaderboardName, memberScore)

      transaction.exec((err, replies) =>
        if replies
          scoreAndRankData = {}
          if replies[0]?
            scoreAndRankData[@scoreKeyOption] = parseFloat(replies[0])
          else
            scoreAndRankData[@scoreKeyOption] = null
          if replies[0]?
            if @reverse
              @redisConnection.zcount(leaderboardName, '-inf', "(#{replies[0]}", (err, count) =>
                scoreAndRankData[@rankKeyOption] = count + 1
                scoreAndRankData[@memberKeyOption] = member
                callback(scoreAndRankData))
            else
              @redisConnection.zcount(leaderboardName, "(#{replies[0]}", '+inf', (err, count) =>
                scoreAndRankData[@rankKeyOption] = count + 1
                scoreAndRankData[@memberKeyOption] = member
                callback(scoreAndRankData))
          else
            scoreAndRankData[@rankKeyOption] = null
            scoreAndRankData[@memberKeyOption] = member
            callback(scoreAndRankData)
      )
    )

  ###
  # Retrieve a page of leaders from the named leaderboard for a given list of members.
  #
  # @param leaderboardName [String] Name of the leaderboard.
  # @param members [Array] Member names.
  # @param options [Hash] Options to be used when retrieving the page from the named leaderboard.
  # @param callback Callback for result of call.
  #
  # @return a page of leaders from the named leaderboard for a given list of members.
  ###
  rankedInListIn: (leaderboardName, members, options = {}, callback) ->
    if not members? or members.length == 0
      return callback([])

    ranksForMembers = []
    transaction = @redisConnection.multi()

    unless options['membersOnly']
      for member in members
        if @reverse
          transaction.zrank(leaderboardName, member)
        else
          transaction.zrevrank(leaderboardName, member)
        transaction.zscore(leaderboardName, member)

    transaction.exec((err, replies) =>
      for member, index in members
        do (member) =>
          data = {}
          data[@memberKeyOption] = member
          unless options['membersOnly']
            if replies[index * 2 + 1]
              data[@scoreKeyOption] = parseFloat(replies[index * 2 + 1])
            else
              data[@scoreKeyOption] = null
              data[@rankKeyOption] = null

          # Retrieve optional member data based on options['withMemberData']
          if options['withMemberData']
            this.memberDataForIn leaderboardName, member, (memberdata) =>
              data[@memberDataKeyOption] = memberdata
              if @reverse
                @redisConnection.zcount(leaderboardName, '-inf', "(#{data[@scoreKeyOption]}", (err, count) =>
                  data[@rankKeyOption] = count + 1
                  ranksForMembers.push(data)
                  # Sort if options['sortBy']
                  if ranksForMembers.length == members.length
                    switch options['sortBy']
                      when 'rank'
                        ranksForMembers.sort((a, b) ->
                          a.rank > b.rank)
                      when 'score'
                        ranksForMembers.sort((a, b) ->
                          a.score > b.score)
                    callback(ranksForMembers))
              else
                @redisConnection.zcount(leaderboardName, "(#{data[@scoreKeyOption]}", '+inf', (err, count) =>
                  data[@rankKeyOption] = count + 1
                  ranksForMembers.push(data)
                  # Sort if options['sortBy']
                  if ranksForMembers.length == members.length
                    switch options['sortBy']
                      when 'rank'
                        ranksForMembers.sort((a, b) ->
                          a.rank > b.rank)
                      when 'score'
                        ranksForMembers.sort((a, b) ->
                          a.score > b.score)
                    callback(ranksForMembers))
          else
            if @reverse
              @redisConnection.zcount(leaderboardName, '-inf', "(#{data[@scoreKeyOption]}", (err, count) =>
                data[@rankKeyOption] = count + 1
                ranksForMembers.push(data)
                # Sort if options['sortBy']
                if ranksForMembers.length == members.length
                  switch options['sortBy']
                    when 'rank'
                      ranksForMembers.sort((a, b) ->
                        a.rank > b.rank)
                    when 'score'
                      ranksForMembers.sort((a, b) ->
                        a.score > b.score)
                  callback(ranksForMembers))
            else
              @redisConnection.zcount(leaderboardName, "(#{data[@scoreKeyOption]}", '+inf', (err, count) =>
                data[@rankKeyOption] = count + 1
                ranksForMembers.push(data)
                # Sort if options['sortBy']
                if ranksForMembers.length == members.length
                  switch options['sortBy']
                    when 'rank'
                      ranksForMembers.sort((a, b) ->
                        a.rank > b.rank)
                    when 'score'
                      ranksForMembers.sort((a, b) ->
                        a.score > b.score)
                  callback(ranksForMembers))
    )

module.exports = CompetitionRankingLeaderboard
