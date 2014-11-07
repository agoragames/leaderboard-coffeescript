describe 'Leaderboard', ->
  before ->
    @redisConnection = redis.createClient(6379, 'localhost')

  beforeEach ->
   @leaderboard = new Leaderboard('highscores', Leaderboard.DEFAULT_OPTIONS)

  afterEach ->
    @redisConnection.flushdb()

  it 'should initialize the leaderboard correctly', (done) ->
    @leaderboard.leaderboardName.should.equal('highscores')
    @leaderboard.reverse.should.be.false
    @leaderboard.pageSize.should.equal(Leaderboard.DEFAULT_PAGE_SIZE)

    done()

  it 'should initialize the leaderboard correctly with options', (done) ->
    updated_options =
      'pageSize': -1
      'reverse': true

    @leaderboard = new Leaderboard('highscores', updated_options)
    @leaderboard.leaderboardName.should.equal('highscores')
    @leaderboard.reverse.should.be.true
    @leaderboard.pageSize.should.equal(Leaderboard.DEFAULT_PAGE_SIZE)

    done()

  it 'should allow you to set custom keys for member, score, rank and member_data', (done) ->
    options =
      'pageSize': Leaderboard.DEFAULT_PAGE_SIZE
      'reverse': false
      'memberKey': 'member_custom'
      'rankKey': 'rank_custom'
      'scoreKey': 'score_custom'
      'memberDataKey': 'member_data_custom'


    @leaderboard = new Leaderboard('highscores', options)

    for index in [0...Leaderboard.DEFAULT_PAGE_SIZE + 1]
      @leaderboard.rankMember("member_#{index}", index, "member_data_#{index}", (reply) -> )

    @leaderboard.leaders(1, {'withMemberData': true}, (reply) ->
      reply.length.should.equal(25)
      reply[0]['member_custom'].should.equal('member_25')
      reply[0]['score_custom'].should.equal(25)
      reply[0]['rank_custom'].should.equal(1)
      reply[0]['member_data_custom'].should.equal('member_data_25')
      done())

  it 'should allow you to change the memberDataNamespace option', (done) ->
    updated_options =
      'memberDataNamespace': 'md'

    @leaderboard = new Leaderboard('highscores', updated_options)
    for index in [0...Leaderboard.DEFAULT_PAGE_SIZE + 1]
      @leaderboard.rankMember("member_#{index}", index, "member_data_#{index}", (reply) -> )

    @leaderboard.redisConnection.exists('highscores:member_data', (err, reply) ->
      reply.should.equal(0))
    @leaderboard.redisConnection.exists('highscores:md', (err, reply) ->
      reply.should.equal(1)
      done())

  it 'should allow you to disconnect the Redis connection', (done) ->
    @leaderboard.disconnect()
    done()

  it 'should allow you to delete a leaderboard', (done) ->
    @leaderboard.rankMember('member', 1, 'Optional member data', (reply) -> )
    @leaderboard.redisConnection.exists('highscores', (err, reply) ->
      reply.should.equal(1))
    @leaderboard.redisConnection.exists('highscores:member_data', (err, reply) ->
      reply.should.equal(1))
    @leaderboard.deleteLeaderboard((reply) -> )
    @leaderboard.redisConnection.exists('highscores', (err, reply) ->
      reply.should.equal(0))
    @leaderboard.redisConnection.exists('highscores:member_data', (err, reply) ->
      reply.should.equal(0))

    done()

  it 'should return the total number of members in the leaderboard', (done) ->
    @leaderboard.totalMembers((reply) ->
      reply.should.equal(0)
      done())

  it 'should allow you to rank a member in the leaderboard and see that reflected in total members', (done) ->
    @leaderboard.rankMember('member', 1, null, (reply) -> )

    @leaderboard.totalMembers((reply) ->
      reply.should.equal(1)
      done())

  it 'should allow you to rank a member in the leaderboard with optional member data and see that reflected in total members', (done) ->
    @leaderboard.rankMember('member', 1, 'Optional member data', (reply) -> )

    @leaderboard.totalMembers((reply) ->
      reply.should.equal(1))

    @leaderboard.memberDataFor('member', (reply) ->
      reply.should.equal('Optional member data')
      done())

  it 'should allow you to retrieve optional member data', (done) ->
    @leaderboard.rankMember('member', 1, 'Optional member data', (reply) -> )

    @leaderboard.memberDataFor('member', (reply) ->
      reply.should.equal('Optional member data')
      done())

  it 'should allow you to update optional member data', (done) ->
    @leaderboard.rankMember('member', 1, 'Optional member data', (reply) -> )

    @leaderboard.memberDataFor('member', (reply) ->
      reply.should.equal('Optional member data'))

    @leaderboard.updateMemberData('member', 'Updated member data', (reply) -> )

    @leaderboard.memberDataFor('member', (reply) ->
      reply.should.equal('Updated member data')
      done())

  it 'should allow you to remove optional member data', (done) ->
    @leaderboard.rankMember('member', 1, 'Optional member data', (reply) -> )

    @leaderboard.memberDataFor('member', (reply) ->
      reply.should.equal('Optional member data'))

    @leaderboard.removeMemberData('member', (reply) -> )

    @leaderboard.memberDataFor('member', (reply) ->
      should_helper.not.exist(reply)
      done())

  it 'should allow you to remove a member', (done) ->
    @leaderboard.rankMember('member', 1, 'Optional member data', (reply) -> )

    @leaderboard.memberDataFor('member', (reply) ->
      reply.should.equal('Optional member data'))

    @leaderboard.removeMember('member', (reply) -> )

    @leaderboard.totalMembers((reply) ->
      reply.should.equal(0))

    @leaderboard.memberDataFor('member', (reply) ->
      should_helper.not.exist(reply)
      done())

  it 'should return the correct total pages', (done) ->
    for index in [0...Leaderboard.DEFAULT_PAGE_SIZE + 1]
      @leaderboard.rankMember("member_#{index}", index, null, (reply) -> )

    @leaderboard.totalPages(5, (reply) ->
      reply.should.equal(6))

    @leaderboard.totalPages(null, (reply) ->
      reply.should.equal(2))

    @leaderboard.totalPages(Leaderboard.DEFAULT_PAGE_SIZE, (reply) ->
      reply.should.equal(2)
      done())

  it 'should return the correct number of members in a given score range', (done) ->
    for index in [0..5]
      @leaderboard.rankMember("member_#{index}", index, null, (reply) -> )

    @leaderboard.totalMembersInScoreRange(2, 4, (reply) ->
      reply.should.equal(3)
      done())

  it 'should return the correct score for a member', (done) ->
    @leaderboard.rankMember('member', 72.4, 'Optional member data', (reply) -> )

    @leaderboard.scoreFor('david', (reply) ->
      should_helper.not.exist(reply))

    @leaderboard.scoreFor('member', (reply) ->
      parseFloat(reply).should.equal(72.4)
      done())

  it 'should return no score for a non member', (done) ->
    @leaderboard.rankMember('member', 72.4, 'Optional member data', (reply) -> )

    @leaderboard.scoreFor('david', (reply) ->
      should_helper.not.exist(reply)
      done())

  it 'should return the correct rank for a member', (done) ->
    for index in [0..5]
      @leaderboard.rankMember("member_#{index}", index, null, (reply) -> )

    @leaderboard.rankFor('unknown', (reply) ->
      should_helper.not.exist(reply))

    @leaderboard.rankFor('member_4', (reply) ->
      reply.should.equal(2)
      done())

  it 'should return the correct rank for the top member', (done) ->
    for index in [0..5]
      @leaderboard.rankMember("member_#{index}", index, null, (reply) -> )

    @leaderboard.rankFor('member_5', (reply) ->
      reply.should.equal(1)
      done())

  it 'should return the correct rank for the bottom member', (done) ->
    for index in [0..5]
      @leaderboard.rankMember("member_#{index}", index, null, (reply) -> )

    @leaderboard.rankFor('member_0', (reply) ->
      reply.should.equal(6)
      done())

  it 'should return no rank for a non member', (done) ->
    for index in [0..5]
      @leaderboard.rankMember("member_#{index}", index, null, (reply) -> )

    @leaderboard.rankFor('unknown', (reply) ->
      should_helper.not.exist(reply)
      done())

  it 'should allow you to change the score for a member', (done) ->
    @leaderboard.rankMember('member', 5, 'Optional member data', (reply) -> )
    @leaderboard.scoreFor('member', (reply) ->
      parseFloat(reply).should.equal(5))
    @leaderboard.changeScoreFor('member', 5, (reply) -> )
    @leaderboard.scoreFor('member', (reply) ->
      parseFloat(reply).should.equal(10))
    @leaderboard.changeScoreFor('member', -5, (reply) -> )
    @leaderboard.scoreFor('member', (reply) ->
      parseFloat(reply).should.equal(5)
      done())

  it 'should allow you to check if a member exists', (done) ->
    @leaderboard.rankMember('member', 10, 'Optional member data', (reply) -> )

    @leaderboard.checkMember('member', (reply) ->
      reply.should.be.true)
    @leaderboard.checkMember('unknown', (reply) ->
      reply.should.be.false
      done())

  it 'should return the correct score and rank', (done) ->
    @leaderboard.rankMember('member', 10, 'Optional member data', (reply) -> )

    @leaderboard.scoreAndRankFor('unknown', (reply) ->
      should_helper.not.exist(reply['score'])
      should_helper.not.exist(reply['rank'])
      reply['member'].should.equal('unknown'))

    @leaderboard.scoreAndRankFor('member', (reply) ->
      reply['score'].should.equal(10)
      reply['rank'].should.equal(1)
      reply['member'].should.equal('member')
      done())

  it 'should allow you to remove members in a given score range', (done) ->
    for index in [0...5]
      @leaderboard.rankMember("member_#{index}", index, null, (reply) -> )

    @leaderboard.totalMembers((reply) ->
      reply.should.equal(5))

    @leaderboard.rankMember('cheater_1', 100, 'Optional member data', (reply) -> )
    @leaderboard.rankMember('cheater_2', 101, 'Optional member data', (reply) -> )
    @leaderboard.rankMember('cheater_3', 102, 'Optional member data', (reply) -> )

    @leaderboard.totalMembers((reply) ->
      reply.should.equal(8))

    @leaderboard.removeMembersInScoreRange(100, 102)

    @leaderboard.totalMembers((reply) ->
      reply.should.equal(5)
      done())

  it 'should allow you to remove members outside a given rank', (done) ->
    for index in [0...6]
      @leaderboard.rankMember("member_#{index}", index, null, (reply) -> )

    @leaderboard.totalMembers((reply) ->
      reply.should.equal(6))

    @leaderboard.removeMembersOutsideRank(3, (reply) ->
      reply.should.equal(3))

    @leaderboard.leaders(1, {'withMemberData': true}, (reply) ->
      reply.length.should.equal(3)
      reply[0]['member'].should.equal('member_5')
      reply[2]['member'].should.equal('member_3'))

    updated_options =
      'pageSize': -1
      'reverse': true

    reverse_leaderboard = new Leaderboard('reverse_highscores', updated_options)

    for index in [0...5]
      reverse_leaderboard.rankMember("member_#{index}", index, null, (reply) -> )

    reverse_leaderboard.totalMembers((reply) ->
      reply.should.equal(5))

    reverse_leaderboard.removeMembersOutsideRank(3, (reply) ->
      reply.should.equal(2))

    reverse_leaderboard.leaders(1, {'withMemberData': true}, (reply) ->
      reply.length.should.equal(3)
      reply[0]['member'].should.equal('member_0')
      reply[2]['member'].should.equal('member_2')
      done())

  it 'should return the correct information when calling percentile_for', (done) ->
    for index in [1...13]
      @leaderboard.rankMember("member_#{index}", index, null, (reply) -> )

    @leaderboard.percentileFor('member_1', (reply) ->
      reply.should.equal(0))
    @leaderboard.percentileFor('member_2', (reply) ->
      reply.should.equal(9))
    @leaderboard.percentileFor('member_3', (reply) ->
      reply.should.equal(17))
    @leaderboard.percentileFor('member_4', (reply) ->
      reply.should.equal(25))
    @leaderboard.percentileFor('member_12', (reply) ->
      reply.should.equal(92)
      done())

  it 'should always execute the callback when calling percentile_for', (done) ->
    for index in [1...13]
      @leaderboard.rankMember("member_#{index}", index, null, (reply) -> )

    @leaderboard.percentileFor('member_1', (reply) ->
      reply.should.equal(0))
    @leaderboard.percentileFor('member_2', (reply) ->
      reply.should.equal(9))
    @leaderboard.percentileFor('member_3', (reply) ->
      reply.should.equal(17))
    @leaderboard.percentileFor('member_4', (reply) ->
      reply.should.equal(25))
    @leaderboard.percentileFor('member_12', (reply) ->
      reply.should.equal(92))
    @leaderboard.percentileFor('unknown', (reply) ->
      should_helper.not.exist(reply)
      done())

  it 'should return the correct information when calling score_for_percentile', (done) ->
    for index in [1...6]
      @leaderboard.rankMember("member_#{index}", index, null, (reply) -> )

    @leaderboard.scoreForPercentile(0, (reply) ->
      reply.should.equal(1.0))
    @leaderboard.scoreForPercentile(75, (reply) ->
      reply.should.equal(4.0))
    @leaderboard.scoreForPercentile(87.5, (reply) ->
      reply.should.equal(4.5))
    @leaderboard.scoreForPercentile(93.75, (reply) ->
      reply.should.equal(4.75))
    @leaderboard.scoreForPercentile(100, (reply) ->
      reply.should.equal(5.0)
      done())

  it 'should always execute the callback when calling score_for_percentile', (done) ->
    for index in [1...2]
      @leaderboard.rankMember("member_#{index}", index, null, (reply) -> )

    @leaderboard.scoreForPercentile(0, (reply) ->
      reply.should.equal(1.0))
    @leaderboard.scoreForPercentile(101, (reply) ->
      should_helper.not.exist(reply)
      done())

  it 'should return the correct page when calling page_for for a given member', (done) ->
    @leaderboard.pageFor('jones', Leaderboard.DEFAULT_PAGE_SIZE, (reply) ->
      reply.should.equal(0))

    for index in [1..20]
      @leaderboard.rankMember("member_#{index}", index, null, (reply) -> )

    @leaderboard.pageFor('member_17', Leaderboard.DEFAULT_PAGE_SIZE, (reply) ->
      reply.should.equal(1))
    @leaderboard.pageFor('member_11', Leaderboard.DEFAULT_PAGE_SIZE, (reply) ->
      reply.should.equal(1))
    @leaderboard.pageFor('member_10', Leaderboard.DEFAULT_PAGE_SIZE, (reply) ->
      reply.should.equal(1))
    @leaderboard.pageFor('member_1', Leaderboard.DEFAULT_PAGE_SIZE, (reply) ->
      reply.should.equal(1))

    @leaderboard.pageFor('member_17', 10, (reply) ->
      reply.should.equal(1))
    @leaderboard.pageFor('member_11', 10, (reply) ->
      reply.should.equal(1))
    @leaderboard.pageFor('member_10', 10, (reply) ->
      reply.should.equal(2))
    @leaderboard.pageFor('member_1', 10, (reply) ->
      reply.should.equal(2)
      done())

  it 'should set an expire on the leaderboard', (done) ->
    for index in [0...5]
      @leaderboard.rankMember("member_#{index}", index, "Optional member data for member #{index}", (reply) -> )

    @leaderboard.expireLeaderboard(5, (reply) -> )
    @leaderboard.redisConnection.ttl(@leaderboard.leaderboardName, (err, reply) ->
      reply.should.be.below(6).and.above(1))
    @leaderboard.redisConnection.ttl(@leaderboard.memberDataKey(@leaderboard.leaderboardName), (err, reply) ->
      reply.should.be.below(6).and.above(1)
      done())

  it 'should set an expire on the leaderboard using a timestamp', (done) ->
    for index in [0...5]
      @leaderboard.rankMember("member_#{index}", index, "Optional member data for member #{index}", (reply) -> )

    timestamp = Math.round(+new Date() / 1000)
    timestamp += 10

    @leaderboard.expireLeaderboardAt(timestamp, (reply) -> )
    @leaderboard.redisConnection.ttl(@leaderboard.leaderboardName, (err, reply) ->
      reply.should.be.above(0).and.below(11))
    @leaderboard.redisConnection.ttl(@leaderboard.leaderboardName, (err, reply) ->
      reply.should.be.above(0).and.below(11)
      done())

  it 'should return the correct list when calling leaders', (done) ->
    for index in [0..25]
      @leaderboard.rankMember("member_#{index}", index, "Optional member data for member #{index}", (reply) -> )

    @leaderboard.totalMembers((reply) ->
      reply.should.equal(26))

    @leaderboard.leaders(1, {'withMemberData': true}, (reply) ->
      reply[0].score.should.equal(25)
      reply[0].rank.should.equal(1)
      reply[0].member.should.equal('member_25')
      reply[0]['member_data'].should.equal('Optional member data for member 25')
      reply.length.should.equal(25))

    @leaderboard.leaders(2, {'withMemberData': true}, (reply) ->
      reply.length.should.equal(1)
      done())

  it 'should return the correct list when calling ranked in list', (done) ->
    for index in [0..25]
      @leaderboard.rankMember("member_#{index}", index, "Optional member data for member #{index}", (reply) -> )

    @leaderboard.rankedInList(['member_5', 'member_17', 'member_1'], null, (reply) ->
      reply[0].member.should.equal('member_5')
      reply[0].score.should.equal(5)
      reply[0].rank.should.equal(21)
      done())

  it 'should always execute the callback when calling ranked in list', (done) ->
    for index in [0..25]
      @leaderboard.rankMember("member_#{index}", index, "Optional member data for member #{index}", (reply) -> )

    @leaderboard.rankedInList([], null, (reply) ->
      reply.length.should.equal(0)
      done())

  it 'should return the entire leaderboard when calling allLeaders', (done) ->
    for index in [0..25]
      @leaderboard.rankMember("member_#{index}", index, "Optional member data for member #{index}", (reply) -> )

    @leaderboard.allLeaders(null, (reply) ->
      reply.length.should.equal(26)
      done())

  it 'should allow you to retrieve members from a given score range', (done) ->
    for index in [0..25]
      @leaderboard.rankMember("member_#{index}", index, "Optional member data for member #{index}", (reply) -> )

    @leaderboard.membersFromScoreRange(10, 15, null, (reply) ->
      reply.length.should.equal(6)
      reply[0].member.should.equal('member_15')
      reply[5].member.should.equal('member_10')
      done())

  it 'should allow you to retrieve a given set of members in a given rank range', (done) ->
    for index in [0..25]
      @leaderboard.rankMember("member_#{index}", index, "Optional member data for member #{index}", (reply) -> )

    @leaderboard.membersFromRankRange(5, 9, null, (reply) ->
      reply.length.should.equal(5)
      reply[0].member.should.equal('member_21')
      reply[4].member.should.equal('member_17')
      done())

  it 'should return a single member when calling memberAt', (done) ->
    for index in [1..50]
      @leaderboard.rankMember("member_#{index}", index, "Optional member data for member #{index}", (reply) -> )

    @leaderboard.memberAt(1, null, (reply) ->
      reply.length.should.equal(1)
      reply[0].rank.should.equal(1)
      reply[0].score.should.equal(50.0))

    @leaderboard.memberAt(26, null, (reply) ->
      reply[0].rank.should.equal(26)
      done())

  it 'should return the correct list of members around me', (done) ->
    for index in [1..(Leaderboard.DEFAULT_PAGE_SIZE * 3 + 1)]
      @leaderboard.rankMember("member_#{index}", index, "Optional member data for member #{index}", (reply) -> )

    @leaderboard.totalMembers((reply) ->
      reply.should.equal(Leaderboard.DEFAULT_PAGE_SIZE * 3 + 1))

    @leaderboard.aroundMe('member_30', null, (reply) ->
      reply[0].member.should.equal('member_42')
      reply.length.should.equal(Leaderboard.DEFAULT_PAGE_SIZE)
      reply[24].member.should.equal('member_18'))

    @leaderboard.aroundMe('member_1', null, (reply) ->
      reply[0].member.should.equal('member_13')
      reply[12].member.should.equal('member_1')
      done())

  it 'should always execute the callback when fetching the list of members around me', (done) ->
    for index in [1..(Leaderboard.DEFAULT_PAGE_SIZE * 3 + 1)]
      @leaderboard.rankMember("member_#{index}", index, "Optional member data for member #{index}", (reply) -> )

    @leaderboard.totalMembers((reply) ->
      reply.should.equal(Leaderboard.DEFAULT_PAGE_SIZE * 3 + 1))

    @leaderboard.aroundMe('unknown', null, (reply) ->
      reply.length.should.equal(0)
      done())

  it 'should be able to rank multiple members at once', (done) ->
    @leaderboard.totalMembers((reply) ->
      reply.should.equal(0))

    @leaderboard.rankMembers(['member_1', 1, 'member_10', 10], (reply) -> )

    @leaderboard.totalMembers((reply) ->
      reply.should.equal(2)
      done())

  it 'should rank a member in the leaderboard with conditional execution', (done) ->
    highscoreCheck = (member, currentScore, score, memberData, leaderboardOptions) ->
      return true if !currentScore?
      return true if score > currentScore
      false

    @leaderboard.totalMembers((reply) ->
      reply.should.equal(0))
    @leaderboard.rankMemberIf(highscoreCheck, 'david', 1337, null, 'Optional member data', (reply) -> )
    @leaderboard.scoreFor('david', (reply) ->
      reply.should.equal(1337))
    @leaderboard.rankMemberIf(highscoreCheck, 'david', 1336, 1337, 'Optional member data', (reply) -> )
    @leaderboard.scoreFor('david', (reply) ->
      reply.should.equal(1337))
    @leaderboard.rankMemberIf(highscoreCheck, 'david', 1338, 1337, 'Optional member data', (reply) -> )
    @leaderboard.scoreFor('david', (reply) ->
      reply.should.equal(1338)
      done())

  it 'should always execute the callback when ranking a member in the leaderboard with conditional execution', (done) ->
    highscoreCheckAlwaysPass = (member, currentScore, score, memberData, leaderboardOptions) ->
      true
    highscoreCheckAlwaysFail = (member, currentScore, score, memberData, leaderboardOptions) ->
      false

    @leaderboard.totalMembers (reply) =>
      reply.should.equal(0)
      @leaderboard.rankMemberIf highscoreCheckAlwaysPass, 'david', 1337, 1337, 'Optional member data', (reply) =>
        @leaderboard.scoreFor 'david', (reply) =>
          reply.should.equal(1337)
          @leaderboard.rankMemberIf highscoreCheckAlwaysFail, 'david', 1338, 1337, 'Optional member data', (reply) =>
            @leaderboard.scoreFor 'david', (reply) =>
              reply.should.equal(1337)
              done()

  it 'should allow you to merge leaderboards', (done) ->
    foo = new Leaderboard('foo', Leaderboard.DEFAULT_OPTIONS)
    bar = new Leaderboard('bar', Leaderboard.DEFAULT_OPTIONS)
    foobar = new Leaderboard('foobar', Leaderboard.DEFAULT_OPTIONS)

    foo.rankMember('foo_1', 1, null, (reply) ->
      foo.rankMember('foo_2', 2, null, (reply) ->
        bar.rankMember('bar_1', 1, null, (reply) ->
          bar.rankMember('bar_2', 2, null, (reply) ->
            bar.rankMember('bar_3', 3, null, (reply) ->
              foo.mergeLeaderboards('foobar', ['bar'], null, (reply) ->
                reply.should.equal(5)
                foobar.totalMembers((numMembers) ->
                  numMembers.should.equal(5)
                  done())))))))

  it 'should allow you to intersect leaderboards', (done) ->
    foo = new Leaderboard('foo', Leaderboard.DEFAULT_OPTIONS)
    bar = new Leaderboard('bar', Leaderboard.DEFAULT_OPTIONS)
    foobar = new Leaderboard('foobar', Leaderboard.DEFAULT_OPTIONS)

    foo.rankMember('foo_1', 1, null, (reply) ->
      foo.rankMember('foo_2', 2, null, (reply) ->
        foo.rankMember('bar_3', 6, null, (reply) ->
          bar.rankMember('bar_1', 3, null, (reply) ->
            bar.rankMember('foo_1', 4, null, (reply) ->
              bar.rankMember('bar_3', 5, null, (reply) ->
                foo.intersectLeaderboards('foobar', ['bar'], null, (reply) ->
                  reply.should.equal(2)
                  foobar.totalMembers((numMembers) ->
                    numMembers.should.equal(2)
                    done()))))))))

  it 'should allow you to rank a member across multiple leaderboards', (done) ->
    @leaderboard.rankMemberAcross(['some_highscores', 'more_highscores'], 'david', 50000, {'member_name': 'David'}, (reply) ->)
    @leaderboard.leadersIn('some_highscores', 1, null, (reply) ->
      reply.length.should.equal(1))
    @leaderboard.leadersIn('more_highscores', 1, null, (reply) ->
      reply.length.should.equal(1)
      done())

  it 'should return the members only if the members_only option is passed', (done) ->
    for index in [0..25]
      @leaderboard.rankMember("member_#{index}", index, "Optional member data for member #{index}", (reply) -> )

    @leaderboard.leaders(1, {'membersOnly': true}, (reply) ->
      reply[0].should.eql({'member': 'member_25'})
      for member in reply
        member.should.have.keys('member'))

    @leaderboard.allLeaders({'membersOnly': true}, (reply) ->
      reply.length.should.equal(26)
      for member in reply
        member.should.have.keys('member'))

    @leaderboard.membersFromScoreRange(10, 14, {'membersOnly': true}, (reply) ->
      reply.length.should.equal(5)
      for member in reply
        member.should.have.keys('member'))

    @leaderboard.membersFromRankRange(1, 5, {'membersOnly': true}, (reply) ->
      reply.length.should.equal(5)
      for member in reply
        member.should.have.keys('member'))

    @leaderboard.aroundMe('member_10', {'pageSize': 3, 'membersOnly': true}, (reply) ->
      reply.length.should.equal(3)
      for member in reply
        member.should.have.keys('member'))

    @leaderboard.rankedInList(['member_1', 'member_20'], {'membersOnly': true}, (reply) ->
      reply.length.should.equal(2)
      for member in reply
        member.should.have.keys('member'))

    done()
