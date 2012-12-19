redis = require 'redis'

class Leaderboard
  @DEFAULT_PAGE_SIZE = 25

  DEFAULT_OPTIONS = 
    'page_size': @DEFAULT_PAGE_SIZE
    'reverse': false

  @DEFAULT_REDIS_HOST = 'localhost'

  @DEFAULT_REDIS_PORT = 6379

  DEFAULT_REDIS_OPTIONS =
    'host': @DEFAULT_REDIS_HOST
    'port': @DEFAULT_REDIS_PORT

  constructor: (@leaderboard_name, options = DEFAULT_OPTIONS, redis_options = DEFAULT_REDIS_OPTIONS) ->
    @reverse = options['reverse']
    @page_size = options['page_size']
    if @page_size == null || @page_size < 1
      @page_size = Leaderboard.DEFAULT_PAGE_SIZE

    @redis_connection = redis_options['redis_connection']

    if @redis_connection?
      delete redis_options['redis_connection']

    @redis_connection = redis.createClient(redis_options['port'], redis_options['host']) unless @redis_connection?

  rank_member: (member, score, member_data = null, callback) ->
    this.rank_member_in(@leaderboard_name, member, score, member_data, callback)

  rank_member_in: (leaderboard_name, member, score, member_data = null, callback) ->
    transaction = @redis_connection.multi()
    transaction.zadd(leaderboard_name, score, member)
    transaction.hset(this.member_data_key(leaderboard_name), member, member_data) if member_data?
    transaction.exec((err, reply) ->
      callback(reply) if callback)

  member_data_for: (member, callback) ->
    this.member_data_for_in(@leaderboard_name, member, callback)

  member_data_for_in: (leaderboard_name, member, callback) ->
    @redis_connection.hget(this.member_data_key(leaderboard_name), member, (err, reply) ->
      callback(reply) if callback)

  total_members: (callback) ->
    this.total_members_in(@leaderboard_name, callback)

  total_members_in: (leaderboard_name, callback) ->
    @redis_connection.zcard(leaderboard_name, (err, reply) ->
      callback(reply) if callback)

  member_data_key: (leaderboard_name) ->
    "#{leaderboard_name}:member_data"

module.exports = Leaderboard
