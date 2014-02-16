{_} = require('underscore')
{Conditions} = require('../shared/conditions')
{Protocol} = require('../shared/protocol')
pbv = require('../shared/pokebattle_values')
gen = require('./generations')

ConditionHash = {}

createCondition = (condition, effects = {}) ->
  ConditionHash[condition] = effects

# Attaches each condition to the Battle facade.
@attach = (battleFacade) ->
  battle = battleFacade.battle
  for condition in battle.conditions
    if condition not of ConditionHash
      throw new Error("Undefined condition: #{condition}")
    hash = ConditionHash[condition] || {}
    # Attach each condition's event listeners
    for eventName, callback of hash.attach
      battle.on(eventName, callback)

    # Extend battle with each function
    # TODO: Attach to prototype, and only once.
    for funcName, funcRef of hash.extend
      battle[funcName] = funcRef

    for funcName, funcRef of hash.extendFacade
      battleFacade[funcName] = funcRef

# validates an entire team
@validateTeam = (conditions, team, genData) ->
  errors = []
  for condition in conditions
    if condition not of ConditionHash
      throw new Error("Undefined condition: #{condition}")
    validator = ConditionHash[condition].validateTeam
    continue  if !validator
    errors.push(validator(team, genData)...)
  return errors

# validates a single pokemon
@validatePokemon = (conditions, pokemon, prefix) ->
  errors = []
  for condition in conditions
    if condition not of ConditionHash
      throw new Error("Undefined condition: #{condition}")
    validator = ConditionHash[condition].validatePokemon
    continue  if !validator
    errors.push(validator(pokemon, prefix)...)
  return errors

createCondition Conditions.PBV_1000,
  validateTeam: (team, genData) ->
    if pbv.determinePBV(genData, team) > 1000
      return [ "Total team PBV cannot surpass 1,000." ]
    return []

createCondition Conditions.SLEEP_CLAUSE

createCondition Conditions.SPECIES_CLAUSE,
  validateTeam: (team, genData) ->
    errors = []
    species = team.map((p) -> p.name)
    species.sort()
    for i in [1...species.length]
      speciesName = species[i - 1]
      if speciesName == species[i]
        errors.push("Cannot have the same species: #{speciesName}")
      while speciesName == species[i]
        i++
    return errors

createCondition Conditions.EVASION_CLAUSE,
  validatePokemon: (pokemon, genData, prefix) ->
    {moves, ability} = pokemon
    errors = []

    # Check evasion abilities
    if ability in [ "Moody" ]
      errors.push("#{prefix}: #{ability} is banned under Evasion Clause.")

    # Check evasion moves
    for moveName in moves
      move = genData.MoveData[moveName]
      if move.primaryBoostStats? && move.primaryBoostStats.evasion > 0 &&
          move.primaryBoostTarget == 'self'
        errors.push("#{prefix}: #{moveName} is banned under Evasion Clause.")

    return errors

createCondition Conditions.RATED_BATTLE,
  attach:
    end: (winnerId) ->
      index = @getPlayerIndex(winnerId)
      loserId = @playerIds[1 - index]
      ratings = require './ratings'
      ratings.getRatings [ winnerId, loserId ], (err, oldRatings) =>
        ratings.updatePlayers winnerId, loserId, ratings.results.WIN, (err, result) =>
          return @message "An error occurred updating rankings :("  if err
          @message "#{winnerId}: #{oldRatings[0]} -> #{result[0].rating}"
          @message "#{loserId}: #{oldRatings[1]} -> #{result[1].rating}"
          @emit('ratingsUpdated')
          @sendUpdates()

createCondition Conditions.TIMED_BATTLE,
  attach:
    start: ->
      nowTime = (new Date).getTime()
      @playerTimes = {}
      for id in @playerIds
        @playerTimes[id] = nowTime + @DEFAULT_TIMER
      @lastActionTimes = {}
      @startTimer()

    addAction: (playerId, action) ->
      # Record the last action for use
      @lastActionTimes[playerId] = (new Date).getTime()

    undoCompletedRequest: (playerId) ->
      delete @lastActionTimes[playerId]
      @checkPlayerTimes()

    # Show players updated times
    beginTurn: ->
      endTimes = (@endTimeFor(id)  for id in @playerIds)
      @tell(Protocol.UPDATE_TIMERS, endTimes...)

    # Subtract the amount of time between now and a player's last action;
    # this is time they should not be penalized for.
    continueTurn: ->
      now = (new Date).getTime()
      for playerId in Object.keys(@lastActionTimes)
        leftoverTime = now - @lastActionTimes[playerId]
        @playerTimes[playerId] += leftoverTime
        delete @lastActionTimes[playerId]
      endTimes = (@endTimeFor(id)  for id in @playerIds)
      @tell(Protocol.UPDATE_TIMERS, endTimes...)

  extend:
    DEFAULT_TIMER: 5 * 60 * 1000  # five minutes
    TIMER_PER_TURN_INCREASE: 20 * 1000  # twenty seconds

    startTimer: (msecs) ->
      msecs ?= @DEFAULT_TIMER
      check = () =>
        leastRemainingTime = @checkPlayerTimes()
        @startTimer(leastRemainingTime)  if leastRemainingTime > 0
      @timerId = setTimeout(check, msecs)
      @once('end', => clearTimeout(@timerId))

    timeRemainingFor: (playerId) ->
      endTime = @endTimeFor(playerId)
      nowTime = @lastActionTimes[playerId] || (+new Date)
      return endTime - nowTime

    endTimeFor: (playerId) ->
      endTime = @playerTimes[playerId]
      endTime += (@turn - 1) * @TIMER_PER_TURN_INCREASE
      endTime

    checkPlayerTimes: ->
      remainingTimes = []
      timedOutPlayers = []
      for id in @playerIds
        timeRemaining = @timeRemainingFor(id)
        if timeRemaining <= 0
          timedOutPlayers.push(id)
        else
          remainingTimes.push(timeRemaining)

      return Math.min(remainingTimes...)  if timedOutPlayers.length == 0

      loser = @rng.choice(timedOutPlayers, "timer")
      index = @getPlayerIndex(loser)
      winnerIndex = 1 - index
      @timerWin(winnerIndex)
      return 0

    timerWin: (winnerIndex) ->
      @tell(Protocol.TIMER_WIN, winnerIndex)
      @emit('end', @playerIds[winnerIndex])

createCondition Conditions.TEAM_PREVIEW,
  attach:
    initialize: ->
      @arranging = true
      @arranged = {}

    start: ->
      @tell(Protocol.TEAM_PREVIEW)
      @shouldStart = false

  extendFacade:
    arrangeTeam: (playerId, arrangement) ->
      return false  if @battle.hasStarted()
      return false  if arrangement not instanceof Array
      team = @battle.getTeam(playerId)
      return false  if !team
      return false  if arrangement.length != team.size()
      for index, i in arrangement
        return false  if isNaN(index)
        return false  if !team.pokemon[index]
        return false  if arrangement.indexOf(index, i + 1) != -1
      if @battle.arrangeTeam(playerId, arrangement)
        @arranging = false
        @battle.tell(Protocol.REARRANGE_TEAMS, @battle.getArrangements()...)
        @battle.startBattle()
        @battle.sendUpdates()
      return true

  extend:
    arrangeTeam: (playerId, arrangement) ->
      return true  if !@arranging
      team = @getTeam(playerId)
      team.arrange(arrangement)
      @arranged[playerId] = arrangement
      return _.difference(@playerIds, Object.keys(@arranged)).length == 0

    getArrangements: ->
      for playerId in @playerIds
        @arranged[playerId] || [0...@getTeam(playerId).length]
