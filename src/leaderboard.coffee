redis = require 'redis'

class Leaderboard
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

  ###
  # Create a new instance of a leaderboard.
  #
  # @param leaderboardName [String] Name of the leaderboard.
  # @param options [Hash] Options for the leaderboard such as +'pageSize'+.
  # @param redisOptions [Hash] Options for configuring Redis.
  ###
  constructor: (@leaderboardName, options = DEFAULT_OPTIONS, redisOptions = DEFAULT_REDIS_OPTIONS) ->
    @reverse = options['reverse']
    @pageSize = options['pageSize']
    if @pageSize == null || @pageSize < 1
      @pageSize = Leaderboard.DEFAULT_PAGE_SIZE
    @memberKeyOption = options['memberKey'] || 'member'
    @rankKeyOption = options['rankKey'] || 'rank'
    @scoreKeyOption = options['scoreKey'] || 'score'
    @memberDataKeyOption = options['memberDataKey'] || 'member_data'
    @memberDataNamespace = options['memberDataNamespace'] || 'member_data'

    @redisConnection = redisOptions['redis_connection']

    if @redisConnection?
      delete redisOptions['redis_connection']

    @redisConnection = redis.createClient(redisOptions['port'], redisOptions['host']) unless @redisConnection?

  ###
  # Disconnect the Redis connection.
  ###
  disconnect: ->
    @redisConnection.quit((err, reply) -> )

  ###
  # Delete the current leaderboard.
  #
  # @param callback Optional callback for result of call.
  ###
  deleteLeaderboard: (callback) ->
    this.deleteLeaderboardNamed(@leaderboardName, callback)

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
    transaction.exec((err, reply) ->
      callback(reply) if callback)

  ###
  # Rank a member in the leaderboard.
  #
  # @param member [String] Member name.
  # @param score [float] Member score.
  # @param memberData [String] Optional member data.
  # @param callback Optional callback for result of call.
  ###
  rankMember: (member, score, memberData = null, callback) ->
    this.rankMemberIn(@leaderboardName, member, score, memberData, callback)

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
      transaction.hset(this.memberDataKey(leaderboardName), member, memberData) if memberData?
    transaction.exec((err, reply) ->
      callback(reply) if callback)

  ###
  # Rank a member in the leaderboard based on execution of the +rankConditional+.
  #
  # The +rankConditional+ is passed the following parameters:
  #   member: Member name.
  #   currentScore: Current score for the member in the leaderboard.
  #   score: Member score.
  #   memberData: Optional member data.
  #   options: Leaderboard options, e.g. 'reverse': Value of reverse option
  #
  # @param rankConditional [Function] Function which must return +true+ or +false+ that controls whether or not the member is ranked in the leaderboard.
  # @param member [String] Member name.
  # @param score [float] Member score.
  # @param currentScore [float] Current score.
  # @param memberData [String] Optional member data.
  # @param callback Optional callback for result of call.
  ###
  rankMemberIf: (rankConditional, member, score, currentScore, memberData = null, callback) ->
    this.rankMemberIfIn(@leaderboardName, rankConditional, member, score, currentScore, memberData, callback)

  ###
  # Rank a member in the named leaderboard based on execution of the +rankConditional+.
  #
  # The +rankConditional+ is passed the following parameters:
  #   member: Member name.
  #   currentScore: Current score for the member in the leaderboard.
  #   score: Member score.
  #   memberData: Optional member data.
  #   options: Leaderboard options, e.g. 'reverse': Value of reverse option
  #
  # @param leaderboardName [String] Name of the leaderboard.
  # @param rankConditional [Function] Function which must return +true+ or +false+ that controls whether or not the member is ranked in the leaderboard.
  # @param member [String] Member name.
  # @param score [float] Member score.
  # @param currentScore [float] Current score.
  # @param memberData [String] Optional member data.
  # @param callback Optional callback for result of call.
  ###
  rankMemberIfIn: (leaderboardName, rankConditional, member, score, currentScore, memberData = null, callback) ->
    if rankConditional(member, currentScore, score, memberData, {'reverse': @reverse})
      this.rankMemberIn(leaderboardName, member, score, memberData, callback)
    else
      callback(0) if callback

  ###
  # Rank an array of members in the leaderboard.
  #
  # @param membersAndScores [Array] Variable list of members and scores.
  # @param callback Optional callback for result of call.
  ###
  rankMembers: (membersAndScores, callback) ->
    this.rankMembersIn(@leaderboardName, membersAndScores, callback)

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
    transaction.exec((err, reply) ->
      callback(reply) if callback)

  ###
  # Retrieve the optional member data for a given member in the leaderboard.
  #
  # @param member [String] Member name.
  # @param callback Callback for result of call.
  #
  # @return String of optional member data.
  ###
  memberDataFor: (member, callback) ->
    this.memberDataForIn(@leaderboardName, member, callback)

  ###
  # Retrieve the optional member data for a given member in the named leaderboard.
  #
  # @param leaderboardName [String] Name of the leaderboard.
  # @param member [String] Member name.
  # @param callback Callback for result of call.
  #
  # @return String of optional member data.
  ###
  memberDataForIn: (leaderboardName, member, callback) ->
    @redisConnection.hget(this.memberDataKey(leaderboardName), member, (err, reply) ->
      callback(reply))

  ###
  # Update the optional member data for a given member in the leaderboard.
  #
  # @param member [String] Member name.
  # @param memberData [String] Optional member data.
  # @param callback Optional callback for result of call.
  ###
  updateMemberData: (member, memberData, callback) ->
    this.updateMemberDataFor(@leaderboardName, member, memberData, callback)

  ###
  # Update the optional member data for a given member in the named leaderboard.
  #
  # @param leaderboardName [String] Name of the leaderboard.
  # @param member [String] Member name.
  # @param memberData [String] Optional member data.
  # @param callback Optional callback for result of call.
  ###
  updateMemberDataFor: (leaderboardName, member, memberData, callback) ->
    @redisConnection.hset(this.memberDataKey(leaderboardName), member, memberData, (err, reply) ->
      callback(reply) if callback)

  ###
  # Remove the optional member data for a given member in the leaderboard.
  #
  # @param member [String] Member name.
  # @param callback Optional callback for result of call.
  ###
  removeMemberData: (member, callback) ->
    this.remberMemberDataFor(@leaderboardName, member, callback)

  ###
  # Remove the optional member data for a given member in the named leaderboard.
  #
  # @param leaderboardName [String] Name of the leaderboard.
  # @param member [String] Member name.
  # @param callback Optional callback for result of call.
  ###
  remberMemberDataFor: (leaderboardName, member, callback) ->
    @redisConnection.hdel(this.memberDataKey(leaderboardName), member, (err, reply) ->
      callback(reply) if callback)

  ###
  # Remove a member from the leaderboard.
  #
  # @param member [String] Member name.
  # @param callback Optional callback for result of call.
  ###
  removeMember: (member, callback) ->
    this.removeMemberFrom(@leaderboardName, member, callback)

  ###
  # Remove a member from the named leaderboard.
  #
  # @param leaderboardName [String] Name of the leaderboard.
  # @param member [String] Member name.
  # @param callback Optional callback for result of call.
  ###
  removeMemberFrom: (leaderboardName, member, callback) ->
    transaction = @redisConnection.multi()
    transaction.zrem(leaderboardName, member)
    transaction.hdel(this.memberDataKey(leaderboardName), member)
    transaction.exec((err, reply) ->
      callback(reply) if callback)

  ###
  # Retrieve the total number of members in the leaderboard.
  #
  # @return total number of members in the leaderboard.
  # @param callback Callback for result of call.
  ###
  totalMembers: (callback) ->
    this.totalMembersIn(@leaderboardName, callback)

  ###
  # Retrieve the total number of members in the named leaderboard.
  #
  # @param leaderboardName [String] Name of the leaderboard.
  # @param callback Callback for result of call.
  #
  # @return the total number of members in the named leaderboard.
  ###
  totalMembersIn: (leaderboardName, callback) ->
    @redisConnection.zcard(leaderboardName, (err, reply) ->
      callback(reply))

  ###
  # Retrieve the total number of pages in the leaderboard.
  #
  # @param pageSize [int, nil] Page size to be used when calculating the total number of pages.
  # @param callback Callback for result of call.
  #
  # @return the total number of pages in the leaderboard.
  ###
  totalPages: (pageSize = null, callback) ->
    this.totalPagesIn(@leaderboardName, pageSize, callback)

  ###
  # Retrieve the total number of pages in the named leaderboard.
  #
  # @param leaderboardName [String] Name of the leaderboard.
  # @param pageSize [int, nil] Page size to be used when calculating the total number of pages.
  # @param callback Callback for result of call.
  #
  # @return the total number of pages in the named leaderboard.
  ###
  totalPagesIn: (leaderboardName, pageSize = null, callback) ->
    unless pageSize?
      pageSize = @pageSize

    @redisConnection.zcard(leaderboardName, (err, reply) ->
      callback(Math.ceil(reply / pageSize)))

  ###
  # Retrieve the total members in a given score range from the leaderboard.
  #
  # @param minScore [float] Minimum score.
  # @param maxScore [float] Maximum score.
  # @param callback Callback for result of call.
  #
  # @return the total members in a given score range from the leaderboard.
  ###
  totalMembersInScoreRange: (minScore, maxScore, callback) ->
    this.totalMembersInScoreRangeIn(@leaderboardName, minScore, maxScore, callback)

  ###
  # Retrieve the total members in a given score range from the named leaderboard.
  #
  # @param leaderboard_name Name of the leaderboard.
  # @param minScore [float] Minimum score.
  # @param maxScore [float] Maximum score.
  # @param callback Callback for result of call.
  #
  # @return the total members in a given score range from the named leaderboard.
  ###
  totalMembersInScoreRangeIn: (leaderboardName, minScore, maxScore, callback) ->
    @redisConnection.zcount(leaderboardName, minScore, maxScore, (err, reply) ->
      callback(reply))

  ###
  # Change the score for a member in the leaderboard by a score delta which can be positive or negative.
  #
  # @param member [String] Member name.
  # @param delta [float] Score change.
  # @param callback Optional callback for result of call.
  ###
  changeScoreFor: (member, delta, callback) ->
    this.changeScoreForMemberIn(@leaderboardName, member, delta, callback)

  ###
  # Change the score for a member in the named leaderboard by a delta which can be positive or negative.
  #
  # @param leaderboardName [String] Name of the leaderboard.
  # @param member [String] Member name.
  # @param delta [float] Score change.
  # @param callback Optional callback for result of call.
  ###
  changeScoreForMemberIn: (leaderboardName, member, delta, callback) ->
    @redisConnection.zincrby(leaderboardName, delta, member, (err, reply) ->
      callback(reply) if callback)

  ###
  # Retrieve the rank for a member in the leaderboard.
  #
  # @param member [String] Member name.
  # @param callback Callback for result of call.
  #
  # @return the rank for a member in the leaderboard.
  ###
  rankFor: (member, callback) ->
    this.rankForIn(@leaderboardName, member, callback)

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
    process_response = (err, reply) ->
      if reply?
        callback(reply + 1)
      else
        callback()

    if @reverse
      @redisConnection.zrank(leaderboardName, member, process_response)
    else
      @redisConnection.zrevrank(leaderboardName, member, process_response)


  ###
  # Retrieve the score for a member in the leaderboard.
  #
  # @param member Member name.
  # @param callback Callback for result of call.
  #
  # @return the score for a member in the leaderboard or +nil+ if the member is not in the leaderboard.
  ###
  scoreFor: (member, callback) ->
    this.scoreForIn(@leaderboardName, member, callback)

  ###
  # Retrieve the score for a member in the named leaderboard.
  #
  # @param leaderboardName Name of the leaderboard.
  # @param member [String] Member name.
  # @param callback Callback for result of call.
  #
  # @return the score for a member in the leaderboard or +nil+ if the member is not in the leaderboard.
  ###
  scoreForIn: (leaderboardName, member, callback) ->
    @redisConnection.zscore(leaderboardName, member, (err, reply) ->
      if reply?
        callback(parseFloat(reply))
      else
        callback(null))

  ###
  # Check to see if a member exists in the leaderboard.
  #
  # @param member [String] Member name.
  # @param callback Callback for result of call.
  #
  # @return +true+ if the member exists in the leaderboard, +false+ otherwise.
  ###
  checkMember: (member, callback) ->
    this.checkMemberIn(@leaderboardName, member, callback)

  ###
  # Check to see if a member exists in the named leaderboard.
  #
  # @param leaderboardName [String] Name of the leaderboard.
  # @param member [String] Member name.
  # @param callback Callback for result of call.
  #
  # @return +true+ if the member exists in the named leaderboard, +false+ otherwise.
  ###
  checkMemberIn: (leaderboardName, member, callback) ->
    @redisConnection.zscore(leaderboardName, member, (err, reply) ->
      callback(reply?))

  ###
  # Retrieve the score and rank for a member in the leaderboard.
  #
  # @param member [String] Member name.
  # @param callback Callback for result of call.
  #
  # @return the score and rank for a member in the leaderboard as a Hash.
  ###
  scoreAndRankFor: (member, callback) ->
    this.scoreAndRankForIn(@leaderboardName, member, callback)

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
    transaction = @redisConnection.multi()
    transaction.zscore(leaderboardName, member)
    if @reverse
      transaction.zrank(leaderboardName, member)
    else
      transaction.zrevrank(leaderboardName, member)

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
        callback(scoreAndRankData))

  ###
  # Remove members from the leaderboard in a given score range.
  #
  # @param minScore [float] Minimum score.
  # @param maxScore [float] Maximum score.
  # @param callback Optional callback for result of call.
  ###
  removeMembersInScoreRange: (minScore, maxScore, callback) ->
    this.removeMembersInScoreRangeIn(@leaderboardName, minScore, maxScore, callback)

  ###
  # Remove members from the named leaderboard in a given score range.
  #
  # @param leaderboardName [String] Name of the leaderboard.
  # @param minScore [float] Minimum score.
  # @param maxScore [float] Maximum score.
  # @param callback Optional callback for result of call.
  ###
  removeMembersInScoreRangeIn: (leaderboardName, minScore, maxScore, callback) ->
    @redisConnection.zremrangebyscore(leaderboardName, minScore, maxScore, (err, reply) ->
      callback(reply) if callback)

  ###
  # Remove members from the leaderboard outside a given rank.
  #
  # @param rank [int] The rank (inclusive) which we should keep.
  # @param callback Optional callback for result of call.
  # @return the total number of members removed.
  ###
  removeMembersOutsideRank: (rank, callback) ->
    this.removeMembersOutsideRankIn(@leaderboardName, rank, callback)

  ###
  # Remove members from the leaderboard outside a given rank.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param rank [int] The rank (inclusive) which we should keep.
  # @param callback Optional callback for result of call.
  # @return the total number of members removed.
  ###
  removeMembersOutsideRankIn: (leaderboardName, rank, callback) ->
    if @reverse
      @redisConnection.zremrangebyrank(leaderboardName, rank, -1, (err, reply) ->
        callback(reply) if callback)
    else
      @redisConnection.zremrangebyrank(leaderboardName, 0, -(rank) - 1, (err, reply) ->
        callback(reply) if callback)

  ###
  # Retrieve the percentile for a member in the leaderboard.
  #
  # @param member [String] Member name.
  # @param callback Callback for result of call.
  #
  # @return the percentile for a member in the leaderboard. Return +nil+ for a non-existent member.
  ###
  percentileFor: (member, callback) ->
    this.percentileForIn(@leaderboardName, member, callback)

  ###
  # Retrieve the percentile for a member in the named leaderboard.
  #
  # @param leaderboardName [String] Name of the leaderboard.
  # @param member [String] Member name.
  # @param callback Callback for result of call.
  #
  # @return the percentile for a member in the named leaderboard.
  ###
  percentileForIn: (leaderboardName, member, callback) ->
    this.checkMemberIn(leaderboardName, member, (reply) =>
      if reply
        transaction = @redisConnection.multi()
        transaction.zcard(leaderboardName)
        transaction.zrevrank(leaderboardName, member)
        transaction.exec((err, replies) ->
          if replies
            percentile = Math.ceil(parseFloat((parseFloat(replies[0] - replies[1] - 1)) / parseFloat(replies[0]) * 100))
            if @reverse
              callback(100 - percentile)
            else
              callback(percentile)
        )
      else
        callback()
    )

  ###
  # Calculate the score for a given percentile value in the leaderboard.
  #
  # @param percentile [float] Percentile value (0.0 to 100.0 inclusive)
  # @param callback Callback for result of call.
  #
  # @return the calculated score for the requested percentile value. Return +nil+ for an invalid (outside 0-100) percentile or a leaderboard with no members.
  ###
  scoreForPercentile: (percentile, callback) ->
    this.scoreForPercentileIn(@leaderboardName, percentile, callback)

  ###
  # Calculate the score for a given percentile value in the leaderboard.
  #
  # @param leaderboardName [String] Name of the leaderboard.
  # @param percentile [float] Percentile value (0.0 to 100.0 inclusive)
  # @param callback Callback for result of call.
  #
  # @return the calculated score for the requested percentile value. Return +nil+ for an invalid (outside 0-100) percentile or a leaderboard with no members.
  ###
  scoreForPercentileIn: (leaderboardName, percentile, callback) ->
    unless 0 <= percentile <= 100
      return callback()
    if @reverse
      percentile = 100 - percentile
    this.totalMembersIn(leaderboardName, (reply) =>
      totalMembers = reply
      if totalMembers == 0
        return callback()
      else
        index = (totalMembers - 1) * (percentile / 100)
        zrange_args = [leaderboardName, Math.floor(index), Math.ceil(index), 'WITHSCORES']
        @redisConnection.zrange(zrange_args, (err, reply) ->
          # Response format: ["Alice", "123", "Bob", "456"] (i.e. flat list, not member/score tuples)
          lowScore = parseFloat(reply[1])
          if index == Math.floor(index)
            callback(lowScore)
          else
            interpolateFraction = index - Math.floor(index)
            hiScore = parseFloat(reply[3])
            callback(lowScore + interpolateFraction * (hiScore - lowScore))
        )
    )

  ###
  # Determine the page where a member falls in the leaderboard.
  #
  # @param member [String] Member name.
  # @param pageSize [int] Page size to be used in determining page location.
  # @param callback Callback for result of call.
  #
  # @return the page where a member falls in the leaderboard.
  ###
  pageFor: (member, pageSize = @DEFAULT_PAGE_SIZE, callback) ->
    this.pageForIn(@leaderboardName, member, pageSize, callback)

  ###
  # Determine the page where a member falls in the named leaderboard.
  #
  # @param leaderboardName [String] Name of the leaderboard.
  # @param member [String] Member name.
  # @param pageSize [int] Page size to be used in determining page location.
  # @param callback Callback for result of call.
  #
  # @return the page where a member falls in the leaderboard.
  ###
  pageForIn: (leaderboardName, member, pageSize = @DEFAULT_PAGE_SIZE, callback) ->
    transaction = @redisConnection.multi()
    if @reverse
      transaction.zrank(leaderboardName, member)
    else
      transaction.zrevrank(leaderboardName, member)
    transaction.exec((err, replies) ->
      rankForMember = replies[0]
      if rankForMember?
        rankForMember += 1
      else
        rankForMember = 0

      callback(Math.ceil(rankForMember / pageSize))
    )

  ###
  # Expire the current leaderboard in a set number of seconds. Do not use this with
  # leaderboards that utilize member data as there is no facility to cascade the
  # expiration out to the keys for the member data.
  #
  # @param seconds [int] Number of seconds after which the leaderboard will be expired.
  # @param callback Optional callback for result of call.
  ###
  expireLeaderboard: (seconds, callback) ->
    this.expireLeaderboardFor(@leaderboardName, seconds, callback)

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
    transaction.expire(this.memberDataKey(leaderboardName), seconds)
    transaction.exec((err, replies) ->
      callback(replies) if callback)

  ###
  # Expire the current leaderboard at a specific UNIX timestamp. Do not use this with
  # leaderboards that utilize member data as there is no facility to cascade the
  # expiration out to the keys for the member data.
  #
  # @param timestamp [int] UNIX timestamp at which the leaderboard will be expired.
  # @param callback Optional callback for result of call.
  ###
  expireLeaderboardAt: (timestamp, callback) ->
    this.expireLeaderboardAtFor(@leaderboardName, timestamp, callback)

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
    transaction.expireat(this.memberDataKey(leaderboardName), timestamp)
    transaction.exec((err, replies) ->
      callback(replies) if callback)

  ###
  # Retrieve a page of leaders from the leaderboard for a given list of members.
  #
  # @param members [Array] Member names.
  # @param options [Hash] Options to be used when retrieving the page from the leaderboard.
  # @param callback Callback for result of call.
  #
  # @return a page of leaders from the leaderboard for a given list of members.
  ###
  rankedInList: (members, options = {}, callback) ->
    this.rankedInListIn(@leaderboardName, members, options, callback)

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

    unless options['members_only']
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
          unless options['members_only']
            data[@rankKeyOption] = replies[index * 2] + 1
            if replies[index * 2 + 1]
              data[@scoreKeyOption] = parseFloat(replies[index * 2 + 1])
            else
              data[@scoreKeyOption] = null
              data[@rankKeyOption] = null

          # Retrieve optional member data based on options['with_member_data']
          if options['with_member_data']
            this.memberDataForIn leaderboardName, member, (memberdata) =>
              data[@memberDataKeyOption] = memberdata
              ranksForMembers.push(data)
              # Sort if options['sort_by']
              if ranksForMembers.length == members.length
                switch options['sort_by']
                  when 'rank'
                    ranksForMembers.sort((a, b) ->
                      a.rank > b.rank)
                  when 'score'
                    ranksForMembers.sort((a, b) ->
                      a.score > b.score)
                callback(ranksForMembers)
          else
            ranksForMembers.push(data)
            # Sort if options['sort_by']
            if ranksForMembers.length == members.length
              switch options['sort_by']
                when 'rank'
                  ranksForMembers.sort((a, b) ->
                    a.rank > b.rank)
                when 'score'
                  ranksForMembers.sort((a, b) ->
                    a.score > b.score)
              callback(ranksForMembers)
    )

  ###
  # Retrieve a page of leaders from the leaderboard.
  #
  # @param currentPage [int] Page to retrieve from the leaderboard.
  # @param options [Hash] Options to be used when retrieving the page from the leaderboard.
  # @param callback Callback for result of call.
  #
  # @return a page of leaders from the leaderboard.
  ###
  leaders: (currentPage, options = {}, callback) ->
    this.leadersIn(@leaderboardName, currentPage, options, callback)

  ###
  # Retrieve a page of leaders from the named leaderboard.
  #
  # @param leaderboardName [String] Name of the leaderboard.
  # @param currentPage [int] Page to retrieve from the named leaderboard.
  # @param options [Hash] Options to be used when retrieving the page from the named leaderboard.
  # @param callback Callback for result of call.
  #
  # @return a page of leaders from the named leaderboard.
  ###
  leadersIn: (leaderboardName, currentPage, options = {}, callback) ->
    currentPage = 1 if currentPage < 1
    pageSize =  options['page_size'] || options['pageSize'] || @pageSize

    this.totalPages(pageSize, (totalPages) =>
      if currentPage > totalPages
        currentPage = totalPages

      indexForRedis = currentPage - 1
      startingOffset = (indexForRedis * pageSize)
      endingOffset = (startingOffset + pageSize) - 1

      if @reverse
        @redisConnection.zrange(leaderboardName, startingOffset, endingOffset, (err, reply) =>
          this.rankedInListIn(leaderboardName, reply, options, callback))
      else
        @redisConnection.zrevrange(leaderboardName, startingOffset, endingOffset, (err, reply) =>
          this.rankedInListIn(leaderboardName, reply, options, callback))
    )

  ###
  # Retrieve all leaders from the leaderboard.
  #
  # @param options [Hash] Options to be used when retrieving the leaders from the leaderboard.
  # @param callback Callback for result of call.
  #
  # @return the leaders from the leaderboard.
  ###
  allLeaders: (options = {}, callback) ->
    this.allLeadersFrom(@leaderboardName, options, callback)

  ###
  # Retrieves all leaders from the named leaderboard.
  #
  # @param leaderboardName [String] Name of the leaderboard.
  # @param options [Hash] Options to be used when retrieving the leaders from the named leaderboard.
  # @param callback Callback for result of call.
  #
  # @return the named leaderboard.
  ###
  allLeadersFrom: (leaderboardName, options = {}, callback) ->
    if @reverse
      @redisConnection.zrange(leaderboardName, 0, -1, (err, reply) =>
        this.rankedInListIn(leaderboardName, reply, options, callback))
    else
      @redisConnection.zrevrange(leaderboardName, 0, -1, (err, reply) =>
        this.rankedInListIn(leaderboardName, reply, options, callback))

  ###
  # Retrieve members from the leaderboard within a given score range.
  #
  # @param minimumScore [float] Minimum score (inclusive).
  # @param maximumScore [float] Maximum score (inclusive).
  # @param options [Hash] Options to be used when retrieving the data from the leaderboard.
  # @param callback Callback for result of call.
  #
  # @return members from the leaderboard that fall within the given score range.
  ###
  membersFromScoreRange: (minimumScore, maximumScore, options = {}, callback) ->
    this.membersFromScoreRangeIn(@leaderboardName, minimumScore, maximumScore, options, callback)

  ###
  # Retrieve members from the named leaderboard within a given score range.
  #
  # @param leaderboardName [String] Name of the leaderboard.
  # @param minimumScore [float] Minimum score (inclusive).
  # @param maximumScore [float] Maximum score (inclusive).
  # @param options [Hash] Options to be used when retrieving the data from the leaderboard.
  # @param callback Callback for result of call.
  #
  # @return members from the leaderboard that fall within the given score range.
  ###
  membersFromScoreRangeIn: (leaderboardName, minimumScore, maximumScore, options = {}, callback) ->
    if @reverse
      @redisConnection.zrangebyscore(leaderboardName, minimumScore, maximumScore, (err, reply) =>
        this.rankedInListIn(leaderboardName, reply, options, callback))
    else
      @redisConnection.zrevrangebyscore(leaderboardName, maximumScore, minimumScore, (err, reply) =>
        this.rankedInListIn(leaderboardName, reply, options, callback))

  ###
  # Retrieve members from the leaderboard within a given rank range.
  #
  # @param startingRank [int] Starting rank (inclusive).
  # @param endingRank [int] Ending rank (inclusive).
  # @param options [Hash] Options to be used when retrieving the data from the leaderboard.
  # @param callback Callback for result of call.
  #
  # @return members from the leaderboard that fall within the given rank range.
  ###
  membersFromRankRange: (startingRank, endingRank, options = {}, callback) ->
    this.membersFromRankRangeIn(@leaderboardName, startingRank, endingRank, options, callback)

  ###
  # Retrieve members from the named leaderboard within a given rank range.
  #
  # @param leaderboardName [String] Name of the leaderboard.
  # @param startingRank [int] Starting rank (inclusive).
  # @param endingRank [int] Ending rank (inclusive).
  # @param options [Hash] Options to be used when retrieving the data from the leaderboard.
  # @param callback Callback for result of call.
  #
  # @return members from the leaderboard that fall within the given rank range.
  ###
  membersFromRankRangeIn: (leaderboardName, startingRank, endingRank, options, callback) ->
    startingRank -= 1
    if startingRank < 0
      startingRank = 0

    endingRank -= 1
    if endingRank < 0
      endingRank = 0

    if @reverse
      @redisConnection.zrange(leaderboardName, startingRank, endingRank, (err, reply) =>
        this.rankedInListIn(leaderboardName, reply, options, callback))
    else
      @redisConnection.zrevrange(leaderboardName, startingRank, endingRank, (err, reply) =>
        this.rankedInListIn(leaderboardName, reply, options, callback))

  ###
  # Retrieve a member at the specified index from the leaderboard.
  #
  # @param position [int] Position in leaderboard.
  # @param options [Hash] Options to be used when retrieving the member from the leaderboard.
  # @param callback Callback for result of call.
  #
  # @return a member from the leaderboard.
  ###
  memberAt: (position, options = {}, callback) ->
    this.memberAtIn(@leaderboardName, position, options, callback)

  ###
  # Retrieve a member at the specified index from the leaderboard.
  #
  # @param leaderboardName [String] Name of the leaderboard.
  # @param position [int] Position in named leaderboard.
  # @param options [Hash] Options to be used when retrieving the member from the named leaderboard.
  # @param callback Callback for result of call.
  #
  # @return a page of leaders from the named leaderboard.
  ###
  memberAtIn: (leaderboardName, position, options = {}, callback) ->
    this.membersFromRankRangeIn(leaderboardName, position, position, options, callback)

  ###
  # Retrieve a page of leaders from the leaderboard around a given member.
  #
  # @param member [String] Member name.
  # @param options [Hash] Options to be used when retrieving the page from the leaderboard.
  # @param callback Callback for result of call.
  #
  # @return a page of leaders from the leaderboard around a given member.
  ###
  aroundMe: (member, options = {}, callback) ->
    this.aroundMeIn(@leaderboardName, member, options, callback)

  ###
  # Retrieve a page of leaders from the named leaderboard around a given member.
  #
  # @param leaderboardName [String] Name of the leaderboard.
  # @param member [String] Member name.
  # @param options [Hash] Options to be used when retrieving the page from the named leaderboard.
  # @param callback Callback for result of call.
  #
  # @return a page of leaders from the named leaderboard around a given member. Returns an empty array for a non-existent member.
  ###
  aroundMeIn: (leaderboardName, member, options = {}, callback) ->
    pageSize = options['page_size'] || options['pageSize'] ||  @pageSize

    if @reverse
      @redisConnection.zrank(leaderboardName, member, (err, reply) =>
        if reply?
          startingOffset = parseInt(Math.ceil(reply - (pageSize / 2)))
          startingOffset = 0 if startingOffset < 0
          endingOffset = (startingOffset + pageSize) - 1

          @redisConnection.zrange(leaderboardName, startingOffset, endingOffset, (err, reply) =>
            this.rankedInListIn(leaderboardName, reply, options, callback))
        else
          callback([])
          []
      )
    else
      @redisConnection.zrevrank(leaderboardName, member, (err, reply) =>
        if reply?
          startingOffset = parseInt(Math.ceil(reply - (pageSize / 2)))
          startingOffset = 0 if startingOffset < 0
          endingOffset = (startingOffset + pageSize) - 1

          @redisConnection.zrevrange(leaderboardName, startingOffset, endingOffset, (err, reply) =>
            this.rankedInListIn(leaderboardName, reply, options, callback))
        else
          callback([])
          []
      )

  ###
  # Merge leaderboards given by keys with this leaderboard into a named destination leaderboard.
  #
  # @param destination [String] Destination leaderboard name.
  # @param keys [Array] Leaderboards to be merged with the current leaderboard.
  # @param options [Hash] Options for merging the leaderboards.
  # @param callback Callback for result of call.
  ###
  mergeLeaderboards: (destination, keys, options = {'aggregate': 'sum'}, callback) ->
    len = keys.length + 1
    keys.unshift(@leaderboardName)
    keys.unshift(len)
    keys.unshift(destination)
    keys.push("AGGREGATE")
    keys.push(options['aggregate'])
    @redisConnection.zunionstore(keys, (err, reply) ->
      callback(reply) if callback)

  ###
  # Intersect leaderboards given by keys with this leaderboard into a named destination leaderboard.
  #
  # @param destination [String] Destination leaderboard name.
  # @param keys [Array] Leaderboards to be merged with the current leaderboard.
  # @param options [Hash] Options for intersecting the leaderboards.
  # @param callback Callback for result of call.
  ###
  intersectLeaderboards: (destination, keys, options = {'aggregate': 'sum'}, callback) ->
    len = keys.length + 1
    keys.unshift(@leaderboardName)
    keys.unshift(len)
    keys.unshift(destination)
    keys.push("AGGREGATE")
    keys.push(options['aggregate'])
    @redisConnection.zinterstore(keys, (err, reply) ->
      callback(reply) if callback)

  ###
  # Key for retrieving optional member data.
  #
  # @param leaderboardName [String] Name of the leaderboard.
  #
  # @return a key in the form of +leaderboardName:member_data+
  ###
  memberDataKey: (leaderboardName) ->
    "#{leaderboardName}:#{@memberDataNamespace}"

module.exports = Leaderboard
