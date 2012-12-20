redis = require 'redis'

class Leaderboard
  @DEFAULT_pageSize = 25

  DEFAULT_OPTIONS = 
    'pageSize': @DEFAULT_pageSize
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
      @pageSize = Leaderboard.DEFAULT_pageSize

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
      callback(reply) if callback)

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
      callback(reply) if callback)

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
      callback(reply) if callback)

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
        callback(reply + 1) if callback and reply)
    else
      @redisConnection.zrevrank(leaderboardName, member, (err, reply) ->
        callback(reply + 1) if callback and reply)

  scoreFor: (member, callback) ->
    this.scoreForIn(@leaderboardName, member, callback)

  scoreForIn: (leaderboardName, member, callback) ->
    @redisConnection.zscore(leaderboardName, member, (err, reply) ->
      callback(reply) if callback)

  checkMember: (member, callback) ->
    this.checkMemberIn(@leaderboardName, member, callback)

  checkMemberIn: (leaderboardName, member, callback) ->
    @redisConnection.zscore(leaderboardName, member, (err, reply) ->
      callback(reply?) if callback)

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
        callback(scoreAndRankData) if callback)

  removeMembersInScoreRange: (minScore, maxScore, callback) ->
    this.removeMembersInScoreRangeIn(@leaderboardName, minScore, maxScore)

  removeMembersInScoreRangeIn: (leaderboardName, minScore, maxScore, callback) ->
    @redisConnection.zremrangebyscore(leaderboardName, minScore, maxScore, (err, reply) ->
      callback(reply) if callback)

  # percentileFor
  # percentileForIn

  # pageFor
  # pageForIn

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
          data['score'] = replies[index * 2 + 1]        

          # Retrieve optional member data based on options['with_member_data']
          if options['with_member_data']
            # Pull in the bits
            true

          ranksForMembers.push(data)

      # Sort results based on options['sort_by']

      callback(ranksForMembers) if callback
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
          this.rankedInListIn(@leaderboardName, reply, options, callback)
        )
      else
        @redisConnection.zrevrange(leaderboardName, startingOffset, endingOffset, (err, reply) =>
          this.rankedInListIn(@leaderboardName, reply, options, callback)
        )
    )

  memberDataKey: (leaderboardName) ->
    "#{leaderboardName}:member_data"

module.exports = Leaderboard
