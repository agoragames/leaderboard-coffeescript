describe 'CompetitionRankingLeaderboard', ->
  before ->
    @redisConnection = redis.createClient(6379, 'localhost')

  beforeEach ->
    @leaderboard = new CompetitionRankingLeaderboard('ties')

  afterEach ->
    @redisConnection.flushdb()

  it 'should retrieve the correct rankings for #leaders', (done) ->
    @leaderboard.rankMember('member_1', 50, 'member_data_1', (reply) -> )
    @leaderboard.rankMember('member_2', 50, 'member_data_2', (reply) -> )
    @leaderboard.rankMember('member_3', 30, 'member_data_3', (reply) -> )
    @leaderboard.rankMember('member_4', 30, 'member_data_4', (reply) -> )
    @leaderboard.rankMember('member_5', 10, 'member_data_5', (reply) -> )

    @leaderboard.leaders(1, {'with_member_data': true}, (reply) ->
      reply.length.should.equal(5)
      reply[0]['rank'].should.equal(1)
      reply[1]['rank'].should.equal(1)
      reply[2]['rank'].should.equal(3)
      reply[3]['rank'].should.equal(3)
      reply[4]['rank'].should.equal(5)
      done())

  it 'should retrieve the correct rankings for #leaders with different page sizes', (done) ->
    @leaderboard.rankMember('member_1', 50, 'member_data_1', (reply) -> )
    @leaderboard.rankMember('member_2', 50, 'member_data_2', (reply) -> )
    @leaderboard.rankMember('member_3', 30, 'member_data_3', (reply) -> )
    @leaderboard.rankMember('member_4', 30, 'member_data_4', (reply) -> )
    @leaderboard.rankMember('member_5', 10, 'member_data_5', (reply) -> )
    @leaderboard.rankMember('member_6', 50, 'member_data_1', (reply) -> )
    @leaderboard.rankMember('member_7', 50, 'member_data_2', (reply) -> )
    @leaderboard.rankMember('member_8', 30, 'member_data_3', (reply) -> )
    @leaderboard.rankMember('member_9', 30, 'member_data_4', (reply) -> )
    @leaderboard.rankMember('member_10', 10, 'member_data_5', (reply) -> )

    @leaderboard.leaders(1, {'with_member_data': true, 'page_size': 3}, (reply) ->
      reply.length.should.equal(3)
      reply[0]['rank'].should.equal(1)
      reply[1]['rank'].should.equal(1)
      reply[2]['rank'].should.equal(1))

    @leaderboard.leaders(2, {'with_member_data': true, 'page_size': 3}, (reply) ->
      reply.length.should.equal(3)
      reply[0]['rank'].should.equal(1)
      reply[1]['rank'].should.equal(5)
      reply[2]['rank'].should.equal(5)
      done())

  it 'should retrieve the correct rankings for #aroundMe', (done) ->
    @leaderboard.rankMember('member_1', 50, 'member_data_1', (reply) -> )
    @leaderboard.rankMember('member_2', 50, 'member_data_2', (reply) -> )
    @leaderboard.rankMember('member_6', 50, 'member_data_6', (reply) -> )
    @leaderboard.rankMember('member_7', 50, 'member_data_7', (reply) -> )
    @leaderboard.rankMember('member_3', 30, 'member_data_3', (reply) -> )
    @leaderboard.rankMember('member_4', 30, 'member_data_4', (reply) -> )
    @leaderboard.rankMember('member_8', 30, 'member_data_8', (reply) -> )
    @leaderboard.rankMember('member_9', 30, 'member_data_9', (reply) -> )
    @leaderboard.rankMember('member_5', 10, 'member_data_5', (reply) -> )
    @leaderboard.rankMember('member_10', 10, 'member_data_10', (reply) -> )

    @leaderboard.aroundMe('member_4', {'with_member_data': true}, (reply) ->
      reply.length.should.equal(10)
      reply[0]['rank'].should.equal(1)
      reply[4]['rank'].should.equal(5)
      reply[9]['rank'].should.equal(9)
      done())

  it 'should allow you to retrieve the rank of a single member using #rankFor', (done) ->
    @leaderboard.rankMember('member_1', 50, 'member_data_1', (reply) -> )
    @leaderboard.rankMember('member_2', 50, 'member_data_2', (reply) -> )
    @leaderboard.rankMember('member_3', 30, 'member_data_3', (reply) -> )

    @leaderboard.rankFor('member_1', (rank) ->
      rank.should.equal(1))

    @leaderboard.rankFor('member_2', (rank) ->
      rank.should.equal(1))

    @leaderboard.rankFor('member_3', (rank) ->
      rank.should.equal(3)
      done())

  it 'should allow you to retrieve the score and rank of a single member using #scoreAndRankFor', (done) ->
    @leaderboard.rankMember('member_1', 50, 'member_data_1', (reply) -> )
    @leaderboard.rankMember('member_2', 50, 'member_data_2', (reply) -> )
    @leaderboard.rankMember('member_3', 30, 'member_data_3', (reply) -> )

    @leaderboard.scoreAndRankFor('member_1', (data) ->
      data['rank'].should.equal(1))

    @leaderboard.scoreAndRankFor('member_2', (data) ->
      data['rank'].should.equal(1))

    @leaderboard.scoreAndRankFor('member_3', (data) ->
      data['rank'].should.equal(3)
      done())