describe 'TieRankingLeaderboard (reverse)', ->
  before ->
    @redisConnection = redis.createClient(6379, 'localhost')

  beforeEach ->
    updated_options =
      'reverse': true
      'pageSize': TieRankingLeaderboard.DEFAULT_PAGE_SIZE

    @leaderboard = new TieRankingLeaderboard('ties', updated_options)

  afterEach ->
    @redisConnection.flushdb()

  it 'should initialize the leaderboard correctly', (done) ->
    @leaderboard.leaderboardName.should.equal('ties')
    @leaderboard.reverse.should.be.true
    @leaderboard.pageSize.should.equal(TieRankingLeaderboard.DEFAULT_PAGE_SIZE)
    @leaderboard.tiesNamespace.should.equal('ties')

    done()

  it 'should delete the ties ranking internal leaderboard when you delete a leaderboard configured for ties', (done) ->
    @leaderboard.rankMember('member_1', 50, null, (reply) -> )
    @leaderboard.rankMember('member_2', 50, null, (reply) -> )
    @leaderboard.rankMember('member_3', 30, null, (reply) -> )
    @leaderboard.rankMember('member_4', 30, null, (reply) -> )
    @leaderboard.rankMember('member_5', 10, null, (reply) -> )

    @leaderboard.redisConnection.exists('ties:ties', (err, reply) ->
      reply.should.equal(1))

    @leaderboard.deleteLeaderboard((reply) -> )

    @leaderboard.redisConnection.exists('ties:ties', (err, reply) ->
      reply.should.equal(0)
      done())

  it 'should retrieve the correct rankings for #leaders', (done) ->
    @leaderboard.rankMember('member_1', 50, 'member_data_1', (reply) -> )
    @leaderboard.rankMember('member_2', 50, 'member_data_2', (reply) -> )
    @leaderboard.rankMember('member_3', 30, 'member_data_3', (reply) -> )
    @leaderboard.rankMember('member_4', 30, 'member_data_4', (reply) -> )
    @leaderboard.rankMember('member_5', 10, 'member_data_5', (reply) -> )

    @leaderboard.leaders(1, {'withMemberData': true}, (reply) ->
      reply.length.should.equal(5)
      reply[0]['rank'].should.equal(1)
      reply[1]['rank'].should.equal(2)
      reply[2]['rank'].should.equal(2)
      reply[3]['rank'].should.equal(3)
      reply[4]['rank'].should.equal(3)
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

    @leaderboard.leaders(1, {'withMemberData': true, 'pageSize': 3}, (reply) ->
      reply.length.should.equal(3)
      reply[0]['rank'].should.equal(1)
      reply[1]['rank'].should.equal(1)
      reply[2]['rank'].should.equal(2))

    @leaderboard.leaders(2, {'withMemberData': true, 'pageSize': 3}, (reply) ->
      reply.length.should.equal(3)
      reply[0]['rank'].should.equal(2)
      reply[1]['rank'].should.equal(2)
      reply[2]['rank'].should.equal(2)
      done())

  it 'should retrieve the correct rankings for #aroundMe', (done) ->
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

    @leaderboard.aroundMe('member_3', {'withMemberData': true, 'pageSize': 3}, (reply) ->
      reply.length.should.equal(3)
      reply[0]['rank'].should.equal(1)
      reply[1]['rank'].should.equal(2)
      reply[2]['rank'].should.equal(2)
      done())

  it 'should support that removing a single member will also remove their score from the tie scores leaderboard when appropriate', (done) ->
    @leaderboard.rankMember('member_1', 50, 'member_data_1', (reply) -> )
    @leaderboard.rankMember('member_2', 50, 'member_data_2', (reply) -> )
    @leaderboard.rankMember('member_3', 30, 'member_data_3', (reply) -> )

    @leaderboard.removeMemberFrom('ties', 'member_1', (reply) =>
      @leaderboard.totalMembersIn('ties:ties', (reply) =>
        reply.should.equal(2)
        @leaderboard.removeMemberFrom('ties', 'member_2', (reply) =>
          @leaderboard.totalMembersIn('ties:ties', (reply) =>
            reply.should.equal(1)
            @leaderboard.removeMemberFrom('ties', 'member_3', (reply) =>
              @leaderboard.totalMembersIn('ties:ties', (reply) =>
                reply.should.equal(0)
                done()))))))

  it 'should allow you to retrieve the rank of a single member using #rankFor', (done) ->
    @leaderboard.rankMember('member_1', 50, 'member_data_1', (reply) -> )
    @leaderboard.rankMember('member_2', 50, 'member_data_2', (reply) -> )
    @leaderboard.rankMember('member_3', 30, 'member_data_3', (reply) -> )

    @leaderboard.rankFor('member_1', (rank) ->
      rank.should.equal(2))

    @leaderboard.rankFor('member_2', (rank) ->
      rank.should.equal(2))

    @leaderboard.rankFor('member_3', (rank) ->
      rank.should.equal(1)
      done())

  it 'should allow you to retrieve the score and rank of a single member using #scoreAndRankFor', (done) ->
    @leaderboard.rankMember('member_1', 50, 'member_data_1', (reply) -> )
    @leaderboard.rankMember('member_2', 50, 'member_data_2', (reply) -> )
    @leaderboard.rankMember('member_3', 30, 'member_data_3', (reply) -> )

    @leaderboard.scoreAndRankFor('member_1', (data) ->
      data['rank'].should.equal(2))

    @leaderboard.scoreAndRankFor('member_2', (data) ->
      data['rank'].should.equal(2))

    @leaderboard.scoreAndRankFor('member_3', (data) ->
      data['rank'].should.equal(1)
      done())

  it 'should have the correct rankings and scores when using #changeScoreFor', (done) ->
    @leaderboard.rankMember('member_1', 50, 'member_data_1', (reply) -> )
    @leaderboard.rankMember('member_2', 50, 'member_data_2', (reply) -> )
    @leaderboard.rankMember('member_3', 30, 'member_data_3', (reply) -> )
    @leaderboard.rankMember('member_4', 30, 'member_data_4', (reply) -> )
    @leaderboard.rankMember('member_5', 10, 'member_data_5', (reply) -> )
    @leaderboard.changeScoreFor('member_3', 10, (reply) -> )

    done()
    # @leaderboard.rankFor('member_3', (reply) =>
    #   reply.should.equal(3)
    #   @leaderboard.rankFor('member_4', (reply) =>
    #     reply.should.equal(2)
    #     @leaderboard.scoreFor('member_3', (reply) =>
    #       reply.should.equal(40.0)
    #       done())))

  it 'should have the correct rankings and scores when using #changeScoreFor with varying scores', (done) ->
    @leaderboard.rankMember('member_1', 5, 'member_data_1', (reply) -> )
    @leaderboard.rankMember('member_2', 4, 'member_data_2', (reply) -> )
    @leaderboard.rankMember('member_3', 3, 'member_data_3', (reply) -> )
    @leaderboard.rankMember('member_4', 2, 'member_data_4', (reply) -> )
    @leaderboard.rankMember('member_5', 1, 'member_data_5', (reply) -> )
    @leaderboard.changeScoreFor('member_3', 0.5, (reply) -> )

    @leaderboard.rankFor('member_3', (reply) =>
      reply.should.equal(3)
      @leaderboard.rankFor('member_4', (reply) =>
        reply.should.equal(2)
        @leaderboard.scoreFor('member_3', (reply) =>
          reply.should.equal(3.5)
          done())))
