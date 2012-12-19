describe 'Leaderboard', ->
  before ->
    @redis_connection = redis.createClient(6379, 'localhost')

  beforeEach ->
    @leaderboard = new Leaderboard('highscores')
  
  afterEach ->
    @redis_connection.flushdb()

  it 'should initialize the leaderboard correctly', (done) ->
    @leaderboard.leaderboard_name.should.equal('highscores')
    @leaderboard.reverse.should.be.false
    @leaderboard.page_size.should.equal(Leaderboard.DEFAULT_PAGE_SIZE)

    done()

  it 'should initialize the leaderboard correctly with options', (done) ->
    updated_options = 
      'page_size': -1
      'reverse': true

    @leaderboard = new Leaderboard('highscores', updated_options)
    @leaderboard.leaderboard_name.should.equal('highscores')
    @leaderboard.reverse.should.be.true
    @leaderboard.page_size.should.equal(Leaderboard.DEFAULT_PAGE_SIZE)

    done()

  it 'should allow you to disconnect the Redis connection', (done) ->
    @leaderboard.disconnect()
    done()

  it 'should allow you to delete a leaderboard', (done) ->
    @leaderboard.rank_member('member', 1, 'Optional member data', (reply) -> )
    @leaderboard.redis_connection.exists('highscores', (err, reply) ->
      reply.should.equal(1))
    @leaderboard.redis_connection.exists('highscores:member_data', (err, reply) ->
      reply.should.equal(1))
    @leaderboard.delete_leaderboard((reply) -> )
    @leaderboard.redis_connection.exists('highscores', (err, reply) ->
      reply.should.equal(0))
    @leaderboard.redis_connection.exists('highscores:member_data', (err, reply) ->
      reply.should.equal(0))

    done()

  it 'should return the total number of members in the leaderboard', (done) ->
    @leaderboard.total_members((reply) ->
      reply.should.equal(0)
      done())

  it 'should allow you to rank a member in the leaderboard and see that reflected in total members', (done) ->
    @leaderboard.rank_member('member', 1, null, (reply) -> )

    @leaderboard.total_members((reply) ->
      reply.should.equal(1)
      done())

  it 'should allow you to rank a member in the leaderboard with optional member data and see that reflected in total members', (done) ->
    @leaderboard.rank_member('member', 1, 'Optional member data', (reply) -> )

    @leaderboard.total_members((reply) ->
      reply.should.equal(1))
    
    @leaderboard.member_data_for('member', (reply) ->
      reply.should.equal('Optional member data')
      done())

  it 'should allow you to retrieve optional member data', (done) ->
    @leaderboard.rank_member('member', 1, 'Optional member data', (reply) -> )

    @leaderboard.member_data_for('member', (reply) ->
      reply.should.equal('Optional member data')
      done())

  it 'should allow you to update optional member data', (done) ->
    @leaderboard.rank_member('member', 1, 'Optional member data', (reply) -> )

    @leaderboard.member_data_for('member', (reply) ->
      reply.should.equal('Optional member data'))

    @leaderboard.update_member_data('member', 'Updated member data', (reply) -> )

    @leaderboard.member_data_for('member', (reply) ->
      reply.should.equal('Updated member data')
      done())

  it 'should allow you to remove optional member data', (done) ->
    @leaderboard.rank_member('member', 1, 'Optional member data', (reply) -> )

    @leaderboard.member_data_for('member', (reply) ->
      reply.should.equal('Optional member data'))

    @leaderboard.remove_member_data('member', (reply) -> )

    @leaderboard.member_data_for('member', (reply) ->
      should_helper.not.exist(reply)
      done())
