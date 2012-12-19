describe 'Leaderboard', ->
  before ->
    @redis = redis.createClient(6379, 'localhost')

  beforeEach ->
    @leaderboard = new Leaderboard('highscores')
  
  afterEach ->
    @redis.flushdb()

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

  it 'should return the total number of members in the leaderboard', (done) ->
    @leaderboard.total_members((reply) ->
      reply.should.equal(0)
      done())

  it 'should allow you to rank a member in the leaderboard and see that reflected in total members', (done) ->
    @leaderboard.rank_member('member', 1)

    @leaderboard.total_members((reply) ->
      reply.should.equal(1)
      done())

  it 'should allow you to retrieve optional member data', (done) ->
    @leaderboard.rank_member('member', 1, 'Optional member data')

    @leaderboard.member_data_for('member', (reply) ->
      reply.should.equal('Optional member data')
      done())

