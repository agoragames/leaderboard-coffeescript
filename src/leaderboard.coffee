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
  # @param options [Hash] Options for the leaderboard such as +'page_size'+.
  # @param redisOptions [Hash] Options for configuring Redis.
  ###
  constructor: (@leaderboardName, options = DEFAULT_OPTIONS, redisOptions = DEFAULT_REDIS_OPTIONS) ->
    @reverse = options['reverse']
    @pageSize = options['pageSize']
    if @pageSize == null || @pageSize < 1
      @pageSize = Leaderboard.DEFAULT_PAGE_SIZE

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
  ###
  deleteLeaderboard: (callback) ->
    this.deleteLeaderboardNamed(@leaderboardName, callback)

  ###
  # Delete the named leaderboard.
  #
  # @param leaderboardName [String] Name of the leaderboard.
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
  # @param memberData [Hash] Optional member data.
  ###
  rankMember: (member, score, memberData = null, callback) ->
    this.rankMemberIn(@leaderboardName, member, score, memberData, callback)

  ###
  # Rank a member in the named leaderboard.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param member [String] Member name.
  # @param score [float] Member score.
  # @param member_data [Hash] Optional member data.
  ###
  rankMemberIn: (leaderboardName, member, score, memberData = null, callback) ->
    transaction = @redisConnection.multi()
    transaction.zadd(leaderboardName, score, member)
    transaction.hset(this.memberDataKey(leaderboardName), member, memberData) if memberData?
    transaction.exec((err, reply) ->
      callback(reply) if callback)

  ###
  # Rank a member in the leaderboard based on execution of the +rank_conditional+. 
  #
  # The +rank_conditional+ is passed the following parameters:
  #   member: Member name.
  #   current_score: Current score for the member in the leaderboard.
  #   score: Member score.
  #   member_data: Optional member data.
  #   leaderboard_options: Leaderboard options, e.g. :reverse => Value of reverse option
  #
  # @param rank_conditional [lambda] Lambda which must return +true+ or +false+ that controls whether or not the member is ranked in the leaderboard.
  # @param member [String] Member name.
  # @param score [String] Member score.
  # @param member_data [Hash] Optional member_data.
  ###
  rankMemberIf: (rankConditional, member, score, memberData = null, callback) ->
    this.rankMemberIfIn(@leaderboardName, rankConditional, member, score, memberData, callback)

  ###
  # Rank a member in the named leaderboard based on execution of the +rank_conditional+. 
  #
  # The +rank_conditional+ is passed the following parameters:
  #   member: Member name.
  #   current_score: Current score for the member in the leaderboard.
  #   score: Member score.
  #   member_data: Optional member data.
  #   leaderboard_options: Leaderboard options, e.g. :reverse => Value of reverse option
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param rank_conditional [lambda] Lambda which must return +true+ or +false+ that controls whether or not the member is ranked in the leaderboard.
  # @param member [String] Member name.
  # @param score [String] Member score.
  # @param member_data [Hash] Optional member_data.
  ###
  rankMemberIfIn: (leaderboardName, rankConditional, member, score, currentScore, memberData = null, callback) ->
    if rankConditional(member, currentScore, score, memberData, {'reverse': @reverse})
      this.rankMemberIn(leaderboardName, member, score, memberData, callback)

  rankMembers: (membersAndScores, callback) ->
    this.rankMembersIn(@leaderboardName, membersAndScores, callback)

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
  #
  # @return Hash of optional member data.
  ###
  memberDataFor: (member, callback) ->
    this.memberDataForIn(@leaderboardName, member, callback)

  ###
  # Retrieve the optional member data for a given member in the named leaderboard.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param member [String] Member name.
  #
  # @return Hash of optional member data.
  ###
  memberDataForIn: (leaderboardName, member, callback = ->) ->
    @redisConnection.hget(this.memberDataKey(leaderboardName), member, (err, reply) ->
      callback(reply))

  ###
  # Update the optional member data for a given member in the leaderboard.
  #
  # @param member [String] Member name.
  # @param member_data [Hash] Optional member data.
  ###
  updateMemberData: (member, memberData, callback) ->
    this.updateMemberDataFor(@leaderboardName, member, memberData, callback)

  ###
  # Update the optional member data for a given member in the named leaderboard.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param member [String] Member name.
  # @param member_data [Hash] Optional member data.
  ###
  updateMemberDataFor: (leaderboardName, member, memberData, callback) ->
    @redisConnection.hset(this.memberDataKey(leaderboardName), member, memberData, (err, reply) ->
      callback(reply) if callback)

  ###
  # Remove the optional member data for a given member in the leaderboard.
  #
  # @param member [String] Member name.
  ###
  removeMemberData: (member, callback) ->
    this.remberMemberDataFor(@leaderboardName, member, callback)

  ###
  # Remove the optional member data for a given member in the named leaderboard.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param member [String] Member name.
  ###
  remberMemberDataFor: (leaderboardName, member, callback) ->
    @redisConnection.hdel(this.memberDataKey(leaderboardName), member, (err, reply) ->
      callback(reply) if callback)

  ###
  # Remove a member from the leaderboard.
  #
  # @param member [String] Member name.
  ###
  removeMember: (member, callback) ->
    this.removeMemberFrom(@leaderboardName, member, callback)

  ###
  # Remove a member from the named leaderboard.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param member [String] Member name.
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
  ###
  totalMembers: (callback) ->
    this.totalMembersIn(@leaderboardName, callback)

  ###
  # Retrieve the total number of members in the named leaderboard.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  #
  # @return the total number of members in the named leaderboard.
  ###
  totalMembersIn: (leaderboardName, callback) ->
    @redisConnection.zcard(leaderboardName, (err, reply) ->
      callback(reply))

  ###
  # Retrieve the total number of pages in the leaderboard.
  #
  # @param page_size [int, nil] Page size to be used when calculating the total number of pages.
  #
  # @return the total number of pages in the leaderboard.
  ###
  totalPages: (pageSize = null, callback) ->
    this.totalPagesIn(@leaderboardName, pageSize, callback)

  ###
  # Retrieve the total number of pages in the named leaderboard.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param page_size [int, nil] Page size to be used when calculating the total number of pages.
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
  # @param min_score [float] Minimum score.
  # @param max_score [float] Maximum score.
  #
  # @return the total members in a given score range from the leaderboard.
  ###
  totalMembersInScoreRange: (minScore, maxScore, callback) ->
    this.totalMembersInScoreRangeIn(@leaderboardName, minScore, maxScore, callback)

  ###
  # Retrieve the total members in a given score range from the named leaderboard.
  #
  # @param leaderboard_name Name of the leaderboard.
  # @param min_score [float] Minimum score.
  # @param max_score [float] Maximum score.
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
  ###
  changeScoreFor: (member, delta, callback) ->
    this.changeScoreForMemberIn(@leaderboardName, member, delta, callback)

  ###
  # Change the score for a member in the named leaderboard by a delta which can be positive or negative.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param member [String] Member name.
  # @param delta [float] Score change.
  ###
  changeScoreForMemberIn: (leaderboardName, member, delta, callback) ->
    @redisConnection.zincrby(leaderboardName, delta, member, (err, reply) ->
      callback(reply) if callback)

  ###
  # Retrieve the rank for a member in the leaderboard.
  #
  # @param member [String] Member name.
  # 
  # @return the rank for a member in the leaderboard.
  ###
  rankFor: (member, callback) ->
    this.rankForIn(@leaderboardName, member, callback)

  ###
  # Retrieve the rank for a member in the named leaderboard.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param member [String] Member name.
  # 
  # @return the rank for a member in the leaderboard.
  ###
  rankForIn: (leaderboardName, member, callback) ->
    if @reverse
      @redisConnection.zrank(leaderboardName, member, (err, reply) ->
        callback(reply + 1) if reply)
    else
      @redisConnection.zrevrank(leaderboardName, member, (err, reply) ->
        callback(reply + 1) if reply)

  ###
  # Retrieve the score for a member in the leaderboard.
  #
  # @param member Member name.
  #
  # @return the score for a member in the leaderboard or +nil+ if the member is not in the leaderboard.
  ###
  scoreFor: (member, callback) ->
    this.scoreForIn(@leaderboardName, member, callback)

  ###
  # Retrieve the score for a member in the named leaderboard.
  #
  # @param leaderboard_name Name of the leaderboard.
  # @param member [String] Member name.
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
  #
  # @return +true+ if the member exists in the leaderboard, +false+ otherwise.
  ###
  checkMember: (member, callback) ->
    this.checkMemberIn(@leaderboardName, member, callback)

  ###
  # Check to see if a member exists in the named leaderboard.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param member [String] Member name.
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
  #
  # @return the score and rank for a member in the leaderboard as a Hash.
  ###
  scoreAndRankFor: (member, callback) ->
    this.scoreAndRankForIn(@leaderboardName, member, callback)

  ###
  # Retrieve the score and rank for a member in the named leaderboard.
  #
  # @param leaderboard_name [String]Name of the leaderboard.
  # @param member [String] Member name.
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
    transaction.exec((err, replies) ->
      if replies
        scoreAndRankData = {}
        if replies[0]?
          scoreAndRankData['score'] = parseFloat(replies[0])
        else
          scoreAndRankData['score'] = null
        if replies[1]?
          scoreAndRankData['rank'] = replies[1] + 1
        else
          scoreAndRankData['rank'] = null
        scoreAndRankData['member'] = member
        callback(scoreAndRankData))

  ###
  # Remove members from the leaderboard in a given score range.
  #
  # @param min_score [float] Minimum score.
  # @param max_score [float] Maximum score.
  ###
  removeMembersInScoreRange: (minScore, maxScore, callback) ->
    this.removeMembersInScoreRangeIn(@leaderboardName, minScore, maxScore)

  ###
  # Remove members from the named leaderboard in a given score range.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param min_score [float] Minimum score.
  # @param max_score [float] Maximum score.
  ###
  removeMembersInScoreRangeIn: (leaderboardName, minScore, maxScore, callback) ->
    @redisConnection.zremrangebyscore(leaderboardName, minScore, maxScore, (err, reply) ->
      callback(reply) if callback)

  ###
  # Retrieve the percentile for a member in the leaderboard.
  #
  # @param member [String] Member name.
  #
  # @return the percentile for a member in the leaderboard. Return +nil+ for a non-existent member.
  ###
  percentileFor: (member, callback) ->
    this.percentileForIn(@leaderboardName, member, callback)

  ###
  # Retrieve the percentile for a member in the named leaderboard.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param member [String] Member name.
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
    )

  ###
  # Determine the page where a member falls in the leaderboard.
  #
  # @param member [String] Member name.
  # @param page_size [int] Page size to be used in determining page location.
  #
  # @return the page where a member falls in the leaderboard.
  def page_for(member, page_size = DEFAULT_PAGE_SIZE)
  ###
  pageFor: (member, pageSize = @DEFAULT_PAGE_SIZE, callback) ->
    this.pageForIn(@leaderboardName, member, pageSize, callback)

  ###
  # Determine the page where a member falls in the named leaderboard.
  #
  # @param leaderboard [String] Name of the leaderboard.
  # @param member [String] Member name.
  # @param page_size [int] Page size to be used in determining page location.
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
  ###
  expireLeaderboard: (seconds, callback) ->
    this.expireLeaderboardFor(@leaderboardName, seconds, callback)

  ###
  # Expire the given leaderboard in a set number of seconds. Do not use this with
  # leaderboards that utilize member data as there is no facility to cascade the
  # expiration out to the keys for the member data.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param seconds [int] Number of seconds after which the leaderboard will be expired.
  ###
  expireLeaderboardFor: (leaderboardName, seconds, callback) ->
    @redisConnection.expire(leaderboardName, seconds, (err, reply) ->
      callback(reply) if callback)

  ###
  # Expire the current leaderboard at a specific UNIX timestamp. Do not use this with
  # leaderboards that utilize member data as there is no facility to cascade the
  # expiration out to the keys for the member data.
  #
  # @param timestamp [int] UNIX timestamp at which the leaderboard will be expired.
  ###
  expireLeaderboardAt: (timestamp, callback) ->
    this.expireLeaderboardAtFor(@leaderboardName, timestamp, callback)

  ###
  # Expire the given leaderboard at a specific UNIX timestamp. Do not use this with
  # leaderboards that utilize member data as there is no facility to cascade the
  # expiration out to the keys for the member data.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param timestamp [int] UNIX timestamp at which the leaderboard will be expired.
  ###
  expireLeaderboardAtFor: (leaderboardName, timestamp, callback) ->
    @redisConnection.expireat(leaderboardName, timestamp, (err, reply) ->
      callback(reply) if callback)

  ###
  # Retrieve a page of leaders from the leaderboard for a given list of members.
  #
  # @param members [Array] Member names.
  # @param options [Hash] Options to be used when retrieving the page from the leaderboard.
  #
  # @return a page of leaders from the leaderboard for a given list of members.
  ###
  rankedInList: (members, options = {}, callback) ->
    this.rankedInListIn(@leaderboardName, members, options, callback)

  ###
  # Retrieve a page of leaders from the named leaderboard for a given list of members.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param members [Array] Member names.
  # @param options [Hash] Options to be used when retrieving the page from the named leaderboard.
  #
  # @return a page of leaders from the named leaderboard for a given list of members.
  ###
  rankedInListIn: (leaderboardName, members, options = {}, callback) ->
    ranksForMembers = []
    transaction = @redisConnection.multi()
    for member in members
      if @reverse
        transaction.zrank(@leaderboardName, member)
      else
        transaction.zrevrank(@leaderboardName, member)
      transaction.zscore(@leaderboardName, member)

    transaction.exec((err, replies) =>
      for member, index in members
        do (member) =>
          data = {}
          data['member'] = member
          data['rank'] = replies[index * 2] + 1
          if replies[index * 2 + 1]
            data['score'] = parseFloat(replies[index * 2 + 1])
          else
            data['score'] = null
            data['rank'] = null

          # Retrieve optional member data based on options['with_member_data']
          if options['with_member_data']
            this.memberDataForIn @leaderboardName, member, (memberdata) =>
              data['member_data'] = memberdata
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
  # @param current_page [int] Page to retrieve from the leaderboard.
  # @param options [Hash] Options to be used when retrieving the page from the leaderboard.
  #
  # @return a page of leaders from the leaderboard.
  ###
  leaders: (currentPage, options = {}, callback) ->
    this.leadersIn(@leaderboardName, currentPage, options, callback)

  ###
  # Retrieve a page of leaders from the named leaderboard.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param current_page [int] Page to retrieve from the named leaderboard.
  # @param options [Hash] Options to be used when retrieving the page from the named leaderboard.
  #
  # @return a page of leaders from the named leaderboard.
  ###
  leadersIn: (leaderboardName, currentPage, options = {}, callback) ->
    currentPage = 1 if currentPage < 1
    pageSize = options['page_size'] || @pageSize

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
  #
  # @return the leaders from the leaderboard.
  ###
  allLeaders: (options = {}, callback) ->
    this.allLeadersFrom(@leaderboardName, options, callback)

  ###
  # Retrieves all leaders from the named leaderboard.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param options [Hash] Options to be used when retrieving the leaders from the named leaderboard.
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
  # @param minimum_score [float] Minimum score (inclusive).
  # @param maximum_score [float] Maximum score (inclusive).
  # @param options [Hash] Options to be used when retrieving the data from the leaderboard.
  #
  # @return members from the leaderboard that fall within the given score range.
  ###
  membersFromScoreRange: (minimumScore, maximumScore, options = {}, callback) ->
    this.membersFromScoreRangeIn(@leaderboardName, minimumScore, maximumScore, options, callback)

  ###
  # Retrieve members from the named leaderboard within a given score range.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param minimum_score [float] Minimum score (inclusive).
  # @param maximum_score [float] Maximum score (inclusive).
  # @param options [Hash] Options to be used when retrieving the data from the leaderboard.
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
  # @param starting_rank [int] Starting rank (inclusive).
  # @param ending_rank [int] Ending rank (inclusive).
  # @param options [Hash] Options to be used when retrieving the data from the leaderboard.
  #
  # @return members from the leaderboard that fall within the given rank range.
  ###
  membersFromRankRange: (startingRank, endingRank, options = {}, callback) ->
    this.membersFromRankRangeIn(@leaderboardName, startingRank, endingRank, options, callback)

  ###
  # Retrieve members from the named leaderboard within a given rank range.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param starting_rank [int] Starting rank (inclusive).
  # @param ending_rank [int] Ending rank (inclusive).
  # @param options [Hash] Options to be used when retrieving the data from the leaderboard.
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
  #
  # @return a member from the leaderboard.
  ###
  memberAt: (position, options = {}, callback) ->
    this.memberAtIn(@leaderboardName, position, options, callback)

  ###
  # Retrieve a member at the specified index from the leaderboard.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param position [int] Position in named leaderboard.
  # @param options [Hash] Options to be used when retrieving the member from the named leaderboard.
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
  #
  # @return a page of leaders from the leaderboard around a given member.
  ###
  aroundMe: (member, options = {}, callback) ->
    this.aroundMeIn(@leaderboardName, member, options, callback)

  ###
  # Retrieve a page of leaders from the named leaderboard around a given member.
  #
  # @param leaderboard_name [String] Name of the leaderboard.
  # @param member [String] Member name.
  # @param options [Hash] Options to be used when retrieving the page from the named leaderboard.
  #
  # @return a page of leaders from the named leaderboard around a given member. Returns an empty array for a non-existent member.
  ###
  aroundMeIn: (leaderboardName, member, options = {}, callback) ->
    if @reverse
      @redisConnection.zrank(leaderboardName, member, (err, reply) => 
        if reply?
          startingOffset = parseInt(Math.ceil(reply - (@pageSize / 2)))
          startingOffset = 0 if startingOffset < 0
          endingOffset = (startingOffset + @pageSize) - 1

          @redisConnection.zrange(leaderboardName, startingOffset, endingOffset, (err, reply) =>
            this.rankedInListIn(leaderboardName, reply, options, callback))
        else
          []
      )
    else
      @redisConnection.zrevrank(leaderboardName, member, (err, reply) =>
        if reply?
          startingOffset = parseInt(Math.ceil(reply - (@pageSize / 2)))
          startingOffset = 0 if startingOffset < 0
          endingOffset = (startingOffset + @pageSize) - 1

          @redisConnection.zrevrange(leaderboardName, startingOffset, endingOffset, (err, reply) =>
            this.rankedInListIn(leaderboardName, reply, options, callback))
        else
          []
      )

  ###
  # Merge leaderboards given by keys with this leaderboard into a named destination leaderboard.
  #
  # @param destination [String] Destination leaderboard name.
  # @param keys [Array] Leaderboards to be merged with the current leaderboard.
  # @param options [Hash] Options for merging the leaderboards.
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
  # @param leaderboard_name [String] Name of the leaderboard.
  # 
  # @return a key in the form of +leaderboard_name:member_data+
  ###
  memberDataKey: (leaderboardName) ->
    "#{leaderboardName}:member_data"

module.exports = Leaderboard
