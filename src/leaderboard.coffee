redis = require 'redis'

class Leaderboard
  @DEFAULT_PAGE_SIZE = 25

  DEFAULT_OPTIONS = 
    'pageSize': @DEFAULT_PAGE_SIZE
    'reverse': false

  @DEFAULT_REDIS_HOST = 'localhost'

  @DEFAULT_REDIS_PORT = 6379

  DEFAULT_REDIS_OPTIONS =
    'host': @DEFAULT_REDIS_HOST
    'port': @DEFAULT_REDIS_PORT

  constructor: (@leaderboardName, options = DEFAULT_OPTIONS, redisOptions = DEFAULT_REDIS_OPTIONS) ->
    @reverse = options['reverse']
    @pageSize = options['pageSize']
    if @pageSize == null || @pageSize < 1
      @pageSize = Leaderboard.DEFAULT_PAGE_SIZE

    @redisConnection = redisOptions['redis_connection']

    if @redisConnection?
      delete redisOptions['redis_connection']

    @redisConnection = redis.createClient(redisOptions['port'], redisOptions['host']) unless @redisConnection?

  disconnect: ->
    @redisConnection.quit((err, reply) -> )

  deleteLeaderboard: (callback) ->
    this.deleteLeaderboardNamed(@leaderboardName, callback)

  deleteLeaderboardNamed: (leaderboardName, callback) ->
    transaction = @redisConnection.multi()
    transaction.del(leaderboardName)
    transaction.del(this.memberDataKey(leaderboardName))
    transaction.exec((err, reply) ->
      callback(reply) if callback)

  rankMember: (member, score, member_data = null, callback) ->
    this.rankMemberIn(@leaderboardName, member, score, member_data, callback)

  rankMemberIn: (leaderboardName, member, score, member_data = null, callback) ->
    transaction = @redisConnection.multi()
    transaction.zadd(leaderboardName, score, member)
    transaction.hset(this.memberDataKey(leaderboardName), member, member_data) if member_data?
    transaction.exec((err, reply) ->
      callback(reply) if callback)

  # rankMemberIf
  # rankMemberIfIn

  # rankMembers
  # rankMembersIn

  memberDataFor: (member, callback) ->
    this.memberDataForIn(@leaderboardName, member, callback)

  memberDataForIn: (leaderboardName, member, callback = ->) ->
    @redisConnection.hget(this.memberDataKey(leaderboardName), member, (err, reply) ->
      callback(reply))

  updateMemberData: (member, member_data, callback) ->
    this.updateMemberDataFor(@leaderboardName, member, member_data, callback)

  updateMemberDataFor: (leaderboardName, member, member_data, callback) ->
    @redisConnection.hset(this.memberDataKey(leaderboardName), member, member_data, (err, reply) ->
      callback(reply) if callback)

  removeMemberData: (member, callback) ->
    this.remberMemberDataFor(@leaderboardName, member, callback)

  remberMemberDataFor: (leaderboardName, member, callback) ->
    @redisConnection.hdel(this.memberDataKey(leaderboardName), member, (err, reply) ->
      callback(reply) if callback)

  removeMember: (member, callback) ->
    this.removeMemberFrom(@leaderboardName, member, callback)

  removeMemberFrom: (leaderboardName, member, callback) ->
    transaction = @redisConnection.multi()
    transaction.zrem(leaderboardName, member)
    transaction.hdel(this.memberDataKey(leaderboardName), member)
    transaction.exec((err, reply) ->
      callback(reply) if callback)

  totalMembers: (callback) ->
    this.totalMembersIn(@leaderboardName, callback)

  totalMembersIn: (leaderboardName, callback) ->
    @redisConnection.zcard(leaderboardName, (err, reply) ->
      callback(reply))

  totalPages: (pageSize = null, callback) ->
    this.totalPagesIn(@leaderboardName, pageSize, callback)

  totalPagesIn: (leaderboardName, pageSize = null, callback) ->
    unless pageSize?
      pageSize = @pageSize

    @redisConnection.zcard(leaderboardName, (err, reply) ->
      callback(Math.ceil(reply / pageSize)))

  totalMembersInScoreRange: (minScore, maxScore, callback) ->
    this.totalMembersInScoreRangeIn(@leaderboardName, minScore, maxScore, callback)

  totalMembersInScoreRangeIn: (leaderboardName, minScore, maxScore, callback) ->
    @redisConnection.zcount(leaderboardName, minScore, maxScore, (err, reply) ->
      callback(reply))

  changeScoreFor: (member, delta, callback) ->
    this.changeScoreForMemberIn(@leaderboardName, member, delta, callback)

  changeScoreForMemberIn: (leaderboardName, member, delta, callback) ->
    @redisConnection.zincrby(leaderboardName, delta, member, (err, reply) ->
      callback(reply) if callback)

  rankFor: (member, callback) ->
    this.rankForIn(@leaderboardName, member, callback)

  rankForIn: (leaderboardName, member, callback) ->
    if @reverse
      @redisConnection.zrank(leaderboardName, member, (err, reply) ->
        callback(reply + 1) if reply)
    else
      @redisConnection.zrevrank(leaderboardName, member, (err, reply) ->
        callback(reply + 1) if reply)

  scoreFor: (member, callback) ->
    this.scoreForIn(@leaderboardName, member, callback)

  scoreForIn: (leaderboardName, member, callback) ->
    @redisConnection.zscore(leaderboardName, member, (err, reply) ->
      callback(reply))

  checkMember: (member, callback) ->
    this.checkMemberIn(@leaderboardName, member, callback)

  checkMemberIn: (leaderboardName, member, callback) ->
    @redisConnection.zscore(leaderboardName, member, (err, reply) ->
      callback(reply?))

  scoreAndRankFor: (member, callback) ->
    this.scoreAndRankForIn(@leaderboardName, member, callback)

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

  removeMembersInScoreRange: (minScore, maxScore, callback) ->
    this.removeMembersInScoreRangeIn(@leaderboardName, minScore, maxScore)

  removeMembersInScoreRangeIn: (leaderboardName, minScore, maxScore, callback) ->
    @redisConnection.zremrangebyscore(leaderboardName, minScore, maxScore, (err, reply) ->
      callback(reply) if callback)

  percentileFor: (member, callback) ->
    this.percentileForIn(@leaderboardName, member, callback)

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

  pageFor: (member, pageSize = @DEFAULT_PAGE_SIZE, callback) ->
    this.pageForIn(@leaderboardName, member, pageSize, callback)

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

  expireLeaderboard: (seconds, callback) ->
    this.expireLeaderboardFor(@leaderboardName, seconds, callback)

  expireLeaderboardFor: (leaderboardName, seconds, callback) ->
    @redisConnection.expire(leaderboardName, seconds, (err, reply) ->
      callback(reply) if callback)

  expireLeaderboardAt: (timestamp, callback) ->
    this.expireLeaderboardAtFor(@leaderboardName, timestamp, callback)

  expireLeaderboardAtFor: (leaderboardName, timestamp, callback) ->
    @redisConnection.expireat(leaderboardName, timestamp, (err, reply) ->
      callback(reply) if callback)

  rankedInList: (members, options = {}, callback) ->
    this.rankedInListIn(@leaderboardName, members, options, callback)

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

  leaders: (currentPage, options = {}, callback) ->
    this.leadersIn(@leaderboardName, currentPage, options, callback)

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

  allLeaders: (options = {}, callback) ->
    this.allLeadersFrom(@leaderboardName, options, callback)

  allLeadersFrom: (leaderboardName, options = {}, callback) ->
    if @reverse
      @redisConnection.zrange(leaderboardName, 0, -1, (err, reply) =>
        this.rankedInListIn(leaderboardName, reply, options, callback))
    else
      @redisConnection.zrevrange(leaderboardName, 0, -1, (err, reply) =>
        this.rankedInListIn(leaderboardName, reply, options, callback))

  membersFromScoreRange: (minimumScore, maximumScore, options = {}, callback) ->
    this.membersFromScoreRangeIn(@leaderboardName, minimumScore, maximumScore, options, callback)

  membersFromScoreRangeIn: (leaderboardName, minimumScore, maximumScore, options = {}, callback) ->
    if @reverse
      @redisConnection.zrangebyscore(leaderboardName, minimumScore, maximumScore, (err, reply) =>
        this.rankedInListIn(leaderboardName, reply, options, callback))
    else
      @redisConnection.zrevrangebyscore(leaderboardName, maximumScore, minimumScore, (err, reply) =>
        this.rankedInListIn(leaderboardName, reply, options, callback))

  membersFromRankRange: (startingRank, endingRank, options = {}, callback) ->
    this.membersFromRankRangeIn(@leaderboardName, startingRank, endingRank, options, callback)

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

  memberAt: (position, options = {}, callback) ->
    this.memberAtIn(@leaderboardName, position, options, callback)

  memberAtIn: (leaderboardName, position, options = {}, callback) ->
    this.membersFromRankRangeIn(leaderboardName, position, position, options, callback)

  # aroundMe
  # aroundMeIn

  # mergeLeaderboards
  # intersectLeaderboards

  memberDataKey: (leaderboardName) ->
    "#{leaderboardName}:member_data"

module.exports = Leaderboard
