{_} = require 'underscore'
{Pokemon} = require './pokemon'
{Attachments} = require './attachment'
{Protocol} = require '../shared/protocol'

class @Team
  {SpeciesData} = require '../data/bw'

  constructor: (battle, player, pokemon, @numActive) ->
    # Inject battle dependency
    @battle = battle
    @player = player
    @pokemon = pokemon.map (attributes) =>
      # TODO: Is there a nicer way of doing these injections?
      attributes.battle = battle
      attributes.team = this
      attributes.player = player
      new Pokemon(attributes)
    @attachments = new Attachments()

  at: (index) ->
    @pokemon[index]

  all: ->
    @pokemon.slice(0)

  slice: (args...) ->
    @pokemon.slice(args...)

  indexOf: (pokemon) ->
    @pokemon.indexOf(pokemon)

  first: ->
    @at(0)

  has: (attachment) ->
    @attachments.contains(attachment)

  get: (attachmentName) ->
    @attachments.get(attachmentName)

  attach: (attachment, options={}) ->
    options = _.clone(options)
    attachment = @attachments.push(attachment, options, battle: @battle, team: this)
    if attachment then @battle?.tell(Protocol.TEAM_ATTACH, @player.index, attachment.name)
    attachment

  unattach: (klass) ->
    attachment = @attachments.unattach(klass)
    if attachment then @battle?.tell(Protocol.TEAM_UNATTACH, @player.index, attachment.name)
    attachment

  switch: (player, a, b, options = {}) ->
    unless options.replacing
      @battle.message "#{player.id} withdrew #{@at(a).name}!"
      p.tell(Protocol.SWITCH_OUT, player.index, a)  for p in @battle.players
      s.tell(Protocol.SWITCH_OUT, player.index, a)  for s in @battle.spectators
      p.informSwitch(@at(a))  for p in @battle.getOpponents(@at(a))
    @switchOut(@at(a))

    [@pokemon[a], @pokemon[b]] = [@pokemon[b], @pokemon[a]]
    p.tell(Protocol.SWITCH_IN, player.index, a, b)  for p in @battle.players
    s.tell(Protocol.SWITCH_IN, player.index, a, b)  for s in @battle.spectators

    @battle.message "#{player.id} sent out #{@at(a).name}!"
    # Switches call switch-in events immediately; replacements wait until all
    # replacements have finished switching in.
    @switchIn(@at(a))  unless options.replacing
    @at(a).turnsActive = 0

  beginTurn: ->
    @attachments.query('beginTurn')

  endTurn: ->
    @attachments.query('endTurn')

  switchOut: (pokemon) ->
    @attachments.query('switchOut', pokemon)
    pokemon.switchOut()

  switchIn: (pokemon) ->
    pokemon.switchIn()
    @attachments.query('switchIn', pokemon)

  getAdjacent: (pokemon) ->
    index = @pokemon.indexOf(pokemon)
    adjacent = []
    return adjacent  if index < 0 || index >= @numActive
    adjacent.push(@at(index - 1))  if index > 1
    adjacent.push(@at(index + 1))  if index < @numActive - 1
    adjacent.filter((p) -> p.isAlive())

  getActivePokemon: ->
    @pokemon.slice(0, @numActive)

  getActiveAlivePokemon: ->
    @getActivePokemon().filter((pokemon) -> pokemon.isAlive())

  getAlivePokemon: ->
    @pokemon.filter((pokemon) -> !pokemon.isFainted())

  getActiveFaintedPokemon: ->
    @getActivePokemon().filter((pokemon) -> pokemon.isFainted())

  getFaintedPokemon: ->
    @pokemon.filter((pokemon) -> pokemon.isFainted())

  getBenchedPokemon: ->
    @pokemon.slice(@numActive)

  getAliveBenchedPokemon: ->
    @getBenchedPokemon().filter((pokemon) -> !pokemon.isFainted())

  toJSON: -> {
    "pokemon": @pokemon.map (p) -> p.toJSON()
    "owner": @player.id
  }
