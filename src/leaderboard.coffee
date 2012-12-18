redis = require 'redis'

class Leaderboard
  DEFAULT_PAGE_SIZE = 25

  DEFAULT_OPTIONS = 
    'page_size': DEFAULT_PAGE_SIZE
    'reverse': false

  DEFAULT_REDIS_HOST = 'localhost'

  DEFAULT_REDIS_PORT = 6379

  DEFAULT_REDIS_OPTIONS =
    'host': DEFAULT_REDIS_HOST
    'port': DEFAULT_REDIS_PORT

  constructor: (@leaderboard_name, options = DEFAULT_OPTIONS, redis_options = DEFAULT_REDIS_OPTIONS) ->
    @reverse = options['reverse']
    @page_size = options['page_size']
    if @page_size == null || @page_size < 1
      @page_size = DEFAULT_PAGE_SIZE

    @redis_connection = redis_options['redis_connection']

    if @redis_connection?
      delete redis_options['redis_connection']
    end

    @redis_connection = redis.createClient(redis_options['host'], redis_options['port']) if @redis_connection?

    