{moves} = require('../data/bw')
{Battle, Pokemon, Status, VolatileStatus, Attachment} = require('../').server
{Factory} = require './factory'
should = require 'should'
shared = require './shared'
itemTests = require './bw/items'
moveTests = require './bw/moves'

describe 'Mechanics', ->
  describe 'an attack missing', ->
    it 'deals no damage', ->
      shared.create.call this,
        team1: [Factory('Celebi')]
        team2: [Factory('Magikarp')]
      move = moves['leaf-storm']
      shared.biasRNG.call(this, 'randInt', 'miss', 100)
      defender = @p2
      originalHP = defender.currentHP
      @controller.makeMove(@player1, 'Leaf Storm')
      @controller.makeMove(@player2, 'Splash')
      defender.currentHP.should.equal originalHP

    it 'triggers effects dependent on the move missing', ->
      shared.create.call this,
        team1: [Factory('Hitmonlee')]
        team2: [Factory('Magikarp')]
      move = moves['hi-jump-kick']
      shared.biasRNG.call(this, 'randInt', 'miss', 100)
      mock = @sandbox.mock(move)
      mock.expects('afterMiss').once()
      @controller.makeMove(@player1, 'hi-jump-kick')
      @controller.makeMove(@player2, 'Splash')
      mock.verify()

    it 'does not trigger effects dependent on the move hitting', ->
      shared.create.call this,
        team1: [Factory('Celebi')]
        team2: [Factory('Gyarados')]
      move = moves['hi-jump-kick']
      shared.biasRNG.call(this, 'randInt', 'miss', 100)
      mock = @sandbox.mock(move)
      mock.expects('afterSuccessfulHit').never()
      @controller.makeMove(@player1, 'Hi Jump Kick')
      @controller.makeMove(@player2, 'Splash')
      mock.verify()

  describe 'fainting', ->
    it 'forces a new pokemon to be picked', ->
      shared.create.call this,
        team1: [Factory('Mew'), Factory('Heracross')]
        team2: [Factory('Hitmonchan'), Factory('Heracross')]
      @p2.currentHP = 1
      spy = @sandbox.spy(@player2, 'emit')
      @controller.makeMove(@player1, 'Psychic')
      @controller.makeMove(@player2, 'Mach Punch')
      spy.calledWith('request action').should.be.true

    it 'does not increment the turn count', ->
      shared.create.call this,
        team1: [Factory('Mew'), Factory('Heracross')]
        team2: [Factory('Hitmonchan'), Factory('Heracross')]
      turn = @battle.turn
      @p2.currentHP = 1
      @controller.makeMove(@player1, 'Psychic')
      @controller.makeMove(@player2, 'Mach Punch')
      @battle.turn.should.not.equal turn + 1

    it 'removes the fainted pokemon from the action priority queue', ->
      shared.create.call this,
        team1: [Factory('Mew'), Factory('Heracross')]
        team2: [Factory('Hitmonchan'), Factory('Heracross')]
      @p1.currentHP = 1
      @p2.currentHP = 1
      @controller.makeMove(@player1, 'Psychic')
      @controller.makeMove(@player2, 'Mach Punch')
      @p1.currentHP.should.be.below 1
      @p2.currentHP.should.equal 1

    it 'lets the player switch in a new pokemon', ->
      shared.create.call this,
        team1: [Factory('Mew'), Factory('Heracross')]
        team2: [Factory('Hitmonchan'), Factory('Heracross')]
      @p2.currentHP = 1
      @controller.makeMove(@player1, 'Psychic')
      @controller.makeMove(@player2, 'Mach Punch')
      @controller.makeSwitchByName(@player2, 'Heracross')
      @team2.first().name.should.equal 'Heracross'

  describe 'secondary effect attacks', ->
    it 'can inflict effect on successful hit', ->
      shared.create.call this,
        team1: [Factory('Porygon-Z')]
        team2: [Factory('Porygon-Z')]
      shared.biasRNG.call(this, 'next', 'secondary effect', 0)  # 100% chance
      defender = @p2
      spy = @sandbox.spy(defender, 'attach')

      @controller.makeMove(@player1, 'Iron Head')
      @controller.makeMove(@player2, 'Splash')

      spy.args[0][0].should.eql Attachment.Flinch

  describe 'secondary status attacks', ->
    it 'can inflict effect on successful hit', ->
      shared.create.call this,
        team1: [Factory('Porygon-Z')]
        team2: [Factory('Porygon-Z')]
      shared.biasRNG.call(this, "next", 'secondary status', 0)  # 100% chance
      defender = @p2
      @controller.makeMove(@player1, 'flamethrower')
      @controller.makeMove(@player2, 'Splash')
      defender.hasStatus(Status.BURN).should.be.true

  describe 'the fang attacks', ->
    it 'can inflict two effects at the same time', ->
      shared.create.call this,
        team1: [Factory('Gyarados')]
        team2: [Factory('Gyarados')]
      shared.biasRNG.call(this, "next", "fang status", 0)  # 100% chance
      shared.biasRNG.call(this, "next", "fang flinch", 0)
      defender = @p2
      spy = @sandbox.spy(defender, 'attach')
      @controller.makeMove(@player1, 'ice-fang')
      @controller.makeMove(@player2, 'Splash')

      spy.args[0][0].should.eql Attachment.Flinch
      defender.hasStatus(Status.FREEZE).should.be.true

  describe 'a pokemon with technician', ->
    it "doesn't increase damage if the move has bp > 60", ->
      shared.create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Mew')]
      @controller.makeMove(@player1, 'Ice Punch')
      hp = @p2.currentHP
      @controller.makeMove(@player2, 'Splash')
      (hp - @p2.currentHP).should.equal 84

    it "increases damage if the move has bp <= 60", ->
      shared.create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Shaymin (land)')]
      @controller.makeMove(@player1, 'Bullet Punch')
      hp = @p2.currentHP
      @controller.makeMove(@player2, 'Splash')
      (hp - @p2.currentHP).should.equal 67

  describe 'STAB', ->
    it "gets applied if the move and user share a type", ->
      shared.create.call this,
        team1: [Factory('Heracross')]
        team2: [Factory('Regirock')]
      @controller.makeMove(@player1, 'Megahorn')
      hp = @p2.currentHP
      @controller.makeMove(@player2, 'Splash')
      (hp - @p2.currentHP).should.equal 123

    it "doesn't get applied if the move and user are of different types", ->
      shared.create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Mew')]
      @controller.makeMove(@player1, 'Ice Punch')
      hp = @p2.currentHP
      @controller.makeMove(@player2, 'Splash')
      (hp - @p2.currentHP).should.equal 84

    it 'is 2x if the pokemon has Adaptability', ->
      shared.create.call this,
        team1: [Factory('Porygon-Z')]
        team2: [Factory('Mew')]
      @controller.makeMove(@player1, 'Tri Attack')
      hp = @p2.currentHP
      @controller.makeMove(@player2, 'Splash')
      (hp - @p2.currentHP).should.equal 214

  describe 'turn order', ->
    it 'randomly decides winner if pokemon have the same speed and priority', ->
      shared.create.call this,
        team1: [Factory('Mew')]
        team2: [Factory('Mew')]
      spy = @sandbox.spy(@battle, 'determineTurnOrder')
      shared.biasRNG.call(this, "next", "turn order", .6)
      @battle.recordMove(@id1, moves['psychic'])
      @battle.recordMove(@id2, moves['psychic'])
      @battle.determineTurnOrder().should.eql [
        {id: @id2, pokemon: @p2, priority: 0}
        {id: @id1, pokemon: @p1, priority: 0}
      ]

      @battle.priorityQueue = null

      shared.biasRNG.call(this, "next", "turn order", .4)
      @battle.recordMove(@id1, moves['psychic'])
      @battle.recordMove(@id2, moves['psychic'])
      @battle.determineTurnOrder().should.eql [
        {id: @id1, pokemon: @p1, priority: 0}
        {id: @id2, pokemon: @p2, priority: 0}
      ]

    it 'decides winner by highest priority move', ->
      shared.create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Hitmonchan')]
      spy = @sandbox.spy(@battle, 'determineTurnOrder')
      @battle.recordMove(@id1, moves['mach-punch'])
      @battle.recordMove(@id2, moves['psychic'])
      @battle.determineTurnOrder().should.eql [
        {id: @id1, pokemon: @p1, priority: 1}
        {id: @id2, pokemon: @p2, priority: 0}
      ]

      @battle.priorityQueue = null

      @battle.recordMove(@id1, moves['psychic'])
      @battle.recordMove(@id2, moves['mach-punch'])
      @battle.determineTurnOrder().should.eql [
        {id: @id2, pokemon: @p2, priority: 1}
        {id: @id1, pokemon: @p1, priority: 0}
      ]

    it 'decides winner by speed if priority is equal', ->
      shared.create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Hitmonchan', evs: { speed: 4 })]
      spy = @sandbox.spy(@battle, 'determineTurnOrder')
      @battle.recordMove(@id1, moves['thunderpunch'])
      @battle.recordMove(@id2, moves['thunderpunch'])
      @battle.determineTurnOrder().should.eql [
        {id: @id2, pokemon: @p2, priority: 0}
        {id: @id1, pokemon: @p1, priority: 0}
      ]

  describe 'fainting all the opposing pokemon', ->
    it "doesn't request any more actions from players", ->
      shared.create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Mew')]
      @p2.currentHP = 1
      @controller.makeMove(@player1, 'Mach Punch')
      @controller.makeMove(@player2, 'Psychic')
      @battle.requests.should.not.have.property @player1.id
      @battle.requests.should.not.have.property @player2.id

    it 'ends the battle', ->
      shared.create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Mew')]
      @p2.currentHP = 1
      mock = @sandbox.mock(@controller)
      mock.expects('endBattle').once()
      @controller.makeMove(@player1, 'Mach Punch')
      @controller.makeMove(@player2, 'Psychic')
      mock.verify()

  describe 'a pokemon with a type immunity', ->
    it 'cannot be damaged by a move of that type', ->
      shared.create.call this,
        team1: [Factory('Camerupt')]
        team2: [Factory('Gyarados')]
      @controller.makeMove(@player1, 'Earthquake')
      @controller.makeMove(@player2, 'Dragon Dance')

      @p2.currentHP.should.equal @p2.stat('hp')

  moveTests.test()
  itemTests.test()

  describe 'a confused pokemon', ->
    it "has a 50% chance of hurting itself", ->
      shared.create.call(this)

      shared.biasRNG.call(this, "randInt", 'confusion turns', 1)  # always 1 turn
      @p1.attach(Attachment.Confusion, {@battle})
      shared.biasRNG.call(this, "next", 'confusion', 0)  # always hits

      mock = @sandbox.mock(moves['tackle'])
      mock.expects('execute').never()

      @controller.makeMove(@player1, 'Tackle')
      @controller.makeMove(@player2, 'Splash')

      mock.verify()

      @p1.currentHP.should.be.lessThan @p1.stat('hp')
      @p2.currentHP.should.equal @p2.stat('hp')

    it "snaps out of confusion after a predetermined number of turns", ->
      shared.create.call(this)

      shared.biasRNG.call(this, "randInt", 'confusion turns', 1)  # always 1 turn
      @p1.attach(Attachment.Confusion, {@battle})

      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Splash')

      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Splash')

      @p1.hasAttachment(VolatileStatus.CONFUSION).should.be.false

    it "will not crit the confusion recoil", ->
      shared.create.call(this)

      @p1.attach(Attachment.Confusion, {@battle})
      shared.biasRNG.call(this, "next", 'confusion', 0)  # always recoils
      shared.biasRNG.call(this, 'next', 'ch', 0) # always crits

      spy = @sandbox.spy(@battle.confusionMove, 'isCriticalHit')
      @controller.makeMove(@player1, 'Tackle')
      @controller.makeMove(@player2, 'Tackle')

      spy.returned(false).should.be.true

  describe 'a frozen pokemon', ->
    it "will not execute moves", ->
      shared.create.call(this)

      @p1.attach(Attachment.Freeze)
      shared.biasRNG.call(this, "next", 'unfreeze chance', 1)  # always stays frozen

      mock = @sandbox.mock(moves['tackle'])
      mock.expects('execute').never()

      @controller.makeMove(@player1, 'Tackle')
      @controller.makeMove(@player2, 'Splash')

      mock.verify()

    it "has a 20% chance of unfreezing", ->
      shared.create.call(this)

      @p1.attach(Attachment.Freeze)
      shared.biasRNG.call(this, "next", 'unfreeze chance', 0)  # always unfreezes

      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Splash')

      @p1.hasAttachment(Status.FREEZE).should.be.false

    for moveName in ["Sacred Fire", "Flare Blitz", "Flame Wheel", "Fusion Flare", "Scald"]
      it "automatically unfreezes if using #{moveName}", ->
        shared.create.call(this)

        @p1.attach(Attachment.Freeze)
        shared.biasRNG.call(this, "next", 'unfreeze chance', 1)  # always stays frozen

        @controller.makeMove(@player1, moveName)
        @controller.makeMove(@player2, 'Splash')

        @p1.hasAttachment(Status.FREEZE).should.be.false

  describe "a paralyzed pokemon", ->
    it "has a 25% chance of being fully paralyzed", ->
      shared.create.call(this)

      @p1.attach(Attachment.Paralysis)
      shared.biasRNG.call(this, "next", 'paralyze chance', 0)  # always stays frozen

      mock = @sandbox.mock(moves['tackle'])
      mock.expects('execute').never()

      @controller.makeMove(@player1, 'Tackle')
      @controller.makeMove(@player2, 'Splash')

      mock.verify()

    it "has its speed quartered", ->
      shared.create.call(this)

      speed = @p1.stat('speed')
      @p1.attach(Attachment.Paralysis)

      @p1.stat('speed').should.equal Math.floor(speed / 4)

  describe "Pokemon#turnsActive", ->
    it "is 0 on start of battle", ->
      shared.create.call(this)
      @p1.turnsActive.should.equal 0

    it "is set to 0 when switching in", ->
      shared.create.call(this)
      @p1.turnsActive = 4
      @p1.switchIn(@battle)
      @p1.turnsActive.should.equal 0

    it "increases by 1 when a turn ends", ->
      shared.create.call(this)
      @p1.turnsActive.should.equal 0

      @battle.endTurn()
      @p1.turnsActive.should.equal 1
