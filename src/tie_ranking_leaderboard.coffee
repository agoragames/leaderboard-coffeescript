Leaderboard = require './leaderboard'

class TieRankingLeaderboard extends Leaderboard
  ###
  # Default page size: 25
  ###
  @DEFAULT_PAGE_SIZE = 25

  ###
  # Default options when creating a leaderboard. Page size is 25 and reverse
  # is set to false, meaning various methods will return results in
  # highest-to-lowest order.
  ###
  DEFAULT_OPTIONS =
    'pageSize': @DEFAULT_PAGE_SIZE
    'reverse': false
    'memberKey': 'member'
    'rankKey': 'rank'
    'scoreKey': 'score'
    'memberDataKey': 'member_data'
    'memberDataNamespace': 'member_data'
    'tiesNamespace': 'ties'

  ###
  # Default Redis host: localhost
  ###
  @DEFAULT_REDIS_HOST = 'localhost'

  ###
  # Default Redis post: 6379
  ###
  @DEFAULT_REDIS_PORT = 6379

  ###
  # Default Redis options when creating a connection to Redis. The
  # +DEFAULT_REDIS_HOST+ and +DEFAULT_REDIS_PORT+ will be passed.
  ###
  DEFAULT_REDIS_OPTIONS =
    'host': @DEFAULT_REDIS_HOST
    'port': @DEFAULT_REDIS_PORT

  constructor: (leaderboardName, options = DEFAULT_OPTIONS, redisOptions = DEFAULT_REDIS_OPTIONS) ->
    super

    @tiesNamespace = options['tiesNamespace'] || 'ties'

  ###
  # Delete the named leaderboard.
  #
  # @param leaderboardName [String] Name of the leaderboard.
  # @param callback Optional callback for result of call.
  ###
  deleteLeaderboardNamed: (leaderboardName, callback) ->
    transaction = @redisConnection.multi()
    transaction.del(leaderboardName)
    transaction.del(this.memberDataKey(leaderboardName))
    transaction.del(this.tiesLeaderboardKey(leaderboardName))
    transaction.exec((err, reply) ->
      callback(reply) if callback)

  ###
  # Change the score for a member in the named leaderboard by a delta which can be positive or negative.
  #
  # @param leaderboardName [String] Name of the leaderboard.
  # @param member [String] Member name.
  # @param delta [float] Score change.
  # @param callback Optional callback for result of call.
  ###
  changeScoreForMemberIn: (leaderboardName, member, delta, callback) ->
    this.scoreFor(member, (score) =>
      newScore = score + delta
      @redisConnection.zrevrangebyscore(leaderboardName, score, score, (err, totalMembers) =>
        transaction = @redisConnection.multi()
        transaction.zadd(leaderboardName, newScore, member)
        transaction.zadd(this.tiesLeaderboardKey(leaderboardName), newScore, newScore)
        transaction.exec((err, reply) =>
          if totalMembers.length == 1
            @redisConnection.zrem(this.tiesLeaderboardKey(leaderboardName), score)
          callback(reply) if callback
        )
      )
    )

  ###
  # Rank a member in the named leaderboard.
  #
  # @param leaderboardName [String] Name of the leaderboard.
  # @param member [String] Member name.
  # @param score [float] Member score.
  # @param memberData [String] Optional member data.
  # @param callback Optional callback for result of call.
  ###
  rankMemberIn: (leaderboardName, member, score, memberData = null, callback) ->
    transaction = @redisConnection.multi()
    transaction.zadd(leaderboardName, score, member)
    transaction.zadd(this.tiesLeaderboardKey(leaderboardName), score, score)
    transaction.hset(this.memberDataKey(leaderboardName), member, memberData) if memberData?
    transaction.exec((err, reply) ->
      callback(reply) if callback)

  ###
  # Rank a member across multiple leaderboards.
  #
  # @param leaderboards [Array] Leaderboard names.
  # @param member [String] Member name.
  # @param score [float] Member score.
  # @param member_data [String] Optional member data.
  ###
  rankMemberAcross: (leaderboardNames, member, score, memberData = null, callback) ->
    transaction = @redisConnection.multi()
    for leaderboardName in leaderboardNames
      transaction.zadd(leaderboardName, score, member)
      transaction.zadd(this.tiesLeaderboardKey(leaderboardName), score, score)
      transaction.hset(this.memberDataKey(leaderboardName), member, memberData) if memberData?
    transaction.exec((err, reply) ->
      callback(reply) if callback)

  ###
  # Rank an array of members in the named leaderboard.
  #
  # @param leaderboardName [String] Name of the leaderboard.
  # @param membersAndScores [Array] Variable list of members and scores
  # @param callback Optional callback for result of call.
  ###
  rankMembersIn: (leaderboardName, membersAndScores, callback) ->
    transaction = @redisConnection.multi()
    for index in [0...membersAndScores.length] by 2
      slice = membersAndScores[index...index + 2]
      transaction.zadd(leaderboardName, slice[1], slice[0])
      transaction.zadd(this.tiesLeaderboardKey(leaderboardName), slice[0], slice[0])
    transaction.exec((err, reply) ->
      callback(reply) if callback)

  ###
  # Remove a member from the named leaderboard.
  #
  # @param leaderboardName [String] Name of the leaderboard.
  # @param member [String] Member name.
  # @param callback Optional callback for result of call.
  ###
  removeMemberFrom: (leaderboardName, member, callback) ->
    @redisConnection.zscore(leaderboardName, member, (err, score) =>
      if score?
        if @reverse
          @redisConnection.zrangebyscore(leaderboardName, score, score, (err, members) =>
            transaction = @redisConnection.multi()
            transaction.zrem(leaderboardName, member)
            transaction.zrem(this.tiesLeaderboardKey(leaderboardName), score) if members.length == 1
            transaction.hdel(this.memberDataKey(leaderboardName), member)
            transaction.exec((err, reply) =>
              callback(reply) if callback
            )
          )
        else
          @redisConnection.zrevrangebyscore(leaderboardName, score, score, (err, members) =>
            transaction = @redisConnection.multi()
            transaction.zrem(leaderboardName, member)
            transaction.zrem(this.tiesLeaderboardKey(leaderboardName), score) if members.length == 1
            transaction.hdel(this.memberDataKey(leaderboardName), member)
            transaction.exec((err, reply) =>
              callback(reply) if callback
            )
          )
      else
        callback(null) if callback
    )

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
        @redisConnection.zrank(this.tiesLeaderboardKey(leaderboardName), score, (err, rank) =>
          callback(rank + 1))
      else
        @redisConnection.zrevrank(this.tiesLeaderboardKey(leaderboardName), score, (err, rank) =>
          callback(rank + 1))
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
        transaction.zrank(this.tiesLeaderboardKey(leaderboardName), memberScore)
      else
        transaction.zrevrank(this.tiesLeaderboardKey(leaderboardName), memberScore)

      transaction.exec((err, replies) =>
        if replies
          scoreAndRankData = {}
          if replies[0]?
            scoreAndRankData[@scoreKeyOption] = parseFloat(replies[0])
          else
            scoreAndRankData[@scoreKeyOption] = null
          if replies[1]?
            scoreAndRankData[@rankKeyOption] = replies[1] + 1
          else
            scoreAndRankData[@rankKeyOption] = null
          scoreAndRankData[@memberKeyOption] = member
          callback(scoreAndRankData)))

  ###
  # Remove members from the named leaderboard in a given score range.
  #
  # @param leaderboardName [String] Name of the leaderboard.
  # @param minScore [float] Minimum score.
  # @param maxScore [float] Maximum score.
  # @param callback Optional callback for result of call.
  ###
  removeMembersInScoreRangeIn: (leaderboardName, minScore, maxScore, callback) ->
    transaction = @redisConnection.multi()
    transaction.zremrangebyscore(leaderboardName, minScore, maxScore)
    transaction.zremrangebyscore(this.tiesLeaderboardKey(leaderboardName), minScore, maxScore)
    transaction.exec((err, replies) ->
      callback(replies) if callback)

  ###
  # Expire the given leaderboard in a set number of seconds. Do not use this with
  # leaderboards that utilize member data as there is no facility to cascade the
  # expiration out to the keys for the member data.
  #
  # @param leaderboardName [String] Name of the leaderboard.
  # @param seconds [int] Number of seconds after which the leaderboard will be expired.
  # @param callback Optional callback for result of call.
  ###
  expireLeaderboardFor: (leaderboardName, seconds, callback) ->
    transaction = @redisConnection.multi()
    transaction.expire(leaderboardName, seconds)
    transaction.expire(this.tiesLeaderboardKey(leaderboardName), seconds)
    transaction.expire(this.memberDataKey(leaderboardName), seconds)
    transaction.exec((err, replies) ->
      callback(replies) if callback)

  ###
  # Expire the given leaderboard at a specific UNIX timestamp. Do not use this with
  # leaderboards that utilize member data as there is no facility to cascade the
  # expiration out to the keys for the member data.
  #
  # @param leaderboardName [String] Name of the leaderboard.
  # @param timestamp [int] UNIX timestamp at which the leaderboard will be expired.
  # @param callback Optional callback for result of call.
  ###
  expireLeaderboardAtFor: (leaderboardName, timestamp, callback) ->
    transaction = @redisConnection.multi()
    transaction.expireat(leaderboardName, timestamp)
    transaction.expireat(this.tiesLeaderboardKey(leaderboardName), timestamp)
    transaction.expireat(this.memberDataKey(leaderboardName), timestamp)
    transaction.exec((err, replies) ->
      callback(replies) if callback)

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
                @redisConnection.zrank(this.tiesLeaderboardKey(leaderboardName), data[@scoreKeyOption], (err, reply) =>
                  data[@rankKeyOption] = reply + 1
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
                @redisConnection.zrevrank(this.tiesLeaderboardKey(leaderboardName), data[@scoreKeyOption], (err, reply) =>
                  data[@rankKeyOption] = reply + 1
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
              @redisConnection.zrank(this.tiesLeaderboardKey(leaderboardName), data[@scoreKeyOption], (err, reply) =>
                data[@rankKeyOption] = reply + 1
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
              @redisConnection.zrevrank(this.tiesLeaderboardKey(leaderboardName), data[@scoreKeyOption], (err, reply) =>
                data[@rankKeyOption] = reply + 1
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

  tiesLeaderboardKey: (leaderboardName) ->
    "#{leaderboardName}:#{@tiesNamespace}"

module.exports = TieRankingLeaderboard
