class @BattleQueue
  constructor: (@server) ->
    @queue = []

  queuePlayer: (player) ->
    @queue.push(player)

  pairPlayers: ->
    while @queue.length >= 2
      player1 = @queue.shift()
      player2 = @queue.shift()
      @server?.battles.push([ player1, player2 ])
