restify = require('restify')
generations = require('../server/generations')
learnsets = require('../shared/learnsets')
{makeBiasedRng} = require("../shared/bias_rng")
GenerationJSON = generations.GenerationJSON

getName = (name) ->
  require('./name_map.json')[name]

slugify = (str) ->
  str.toLowerCase().replace(/[^a-z0-9]/g, '-').replace(/\-{2,}/g, '-')

slugifyArray = (array) ->
  hash = {}
  for element in array
    hash[slugify(element)] = element
  hash

attachAPIEndpoints = (server) ->
  for gen in generations.ALL_GENERATIONS
    do (gen) ->
      json = GenerationJSON[gen.toUpperCase()]
      GenMoves = slugifyArray(json.MoveList)
      GenAbilities = slugifyArray(json.AbilityList)
      GenTypes = slugifyArray(json.TypeList)
      try
        # Preload Battle
        {Battle} = require("../server/#{gen}/battle")
      catch
        # TODO: There is no Battle object for this gen

      intGeneration = generations.GENERATION_TO_INT[gen]
      server.get "#{gen}/moves", (req, res, next) ->
        res.send(json.MoveData)
        return next()

      server.get "#{gen}/pokemon", (req, res, next) ->
        res.send(json.FormeData)
        return next()

      server.get "#{gen}/pokemon/:species", (req, res, next) ->
        species = getName(req.params.species)
        return next(new restify.ResourceNotFoundError("Could not find Pokemon: #{req.params.species}"))  if !species
        pokemon = json.FormeData[species]
        res.send(pokemon)
        return next()

      server.get "#{gen}/items", (req, res, next) ->
        res.send(items: json.ItemList)
        return next()

      server.get "#{gen}/moves", (req, res, next) ->
        res.send(moves: json.MoveList)
        return next()

      server.get "#{gen}/moves/:name", (req, res, next) ->
        move = GenMoves[req.params.name]
        return next(new restify.ResourceNotFoundError("Could not find Move: #{req.params.name}"))  if !move
        res.send(pokemon: json.MoveMap[move])
        return next()

      server.get "#{gen}/abilities", (req, res, next) ->
        res.send(abilities: json.AbilityList)
        return next()

      server.get "#{gen}/abilities/:name", (req, res, next) ->
        ability = GenAbilities[req.params.name]
        return next(new restify.ResourceNotFoundError("Could not find Ability: #{req.params.name}"))  if !ability
        res.send(pokemon: json.AbilityMap[ability])
        return next()

      server.get "#{gen}/types", (req, res, next) ->
        res.send(types: json.TypeList)
        return next()

      server.get "#{gen}/types/:name", (req, res, next) ->
        type = GenTypes[req.params.name]
        return next(new restify.ResourceNotFoundError("Could not find Type: #{req.params.name}"))  if !type
        res.send(pokemon: json.TypeMap[type])
        return next()

      server.get "#{gen}/pokemon/:species/moves", (req, res, next) ->
        species = getName(req.params.species)
        pokemon = {species: species}
        moves = learnsets.learnableMoves(GenerationJSON, pokemon, intGeneration)
        return next(new restify.ResourceNotFoundError("Could not find moves for Pokemon: #{req.params.species}"))  if !moves || moves.length == 0
        res.send(moves: moves)
        return next()

      server.get "#{gen}/pokemon/:species/:forme/moves", (req, res, next) ->
        species = getName(req.params.species)
        pokemon = {species: species, forme: req.params.forme}
        moves = learnsets.learnableMoves(GenerationJSON, pokemon, intGeneration)
        return next(new restify.ResourceNotFoundError("Could not find moves for Pokemon: #{req.params.species}"))  if !moves || moves.length == 0
        res.send(moves: moves)
        return next()

      checkMoveset = (req, res, next) ->
        species = getName(req.params.species)
        return next(new restify.ResourceNotFoundError("Could not find Pokemon: #{req.params.species}"))  if !species
        pokemon = {species: species}
        pokemon.forme = req.params.forme  if req.params.forme
        moveset = req.query.moves?.split(/,/) || []
        valid = learnsets.checkMoveset(GenerationJSON, pokemon, intGeneration, moveset)
        errors = []
        errors.push("Invalid moveset")  if !valid
        res.send(errors: errors)
        return next()

      server.get "#{gen}/pokemon/:species/check", checkMoveset
      server.get "#{gen}/pokemon/:species/:forme/check", checkMoveset

      server.put "#{gen}/damagecalc", (req, res, next) ->
        # todo: catch any invalid data.
        moveName = req.params.move
        attacker = req.params.attacker
        defender = req.params.defender

        players = [
          {id: "0", name: "0", team: [attacker]}
          {id: "1", name: "1", team: [defender]}
        ]
        battle = new Battle('id', players, numActive: 1)

        move = battle.getMove(moveName)
        if not move
          return next(new restify.BadRequest("Invalid move #{moveName}"))

        battle.begin()
        attackerPokemon = battle.getTeam("0").at(0)
        defenderPokemon = battle.getTeam("1").at(0)

        # bias the RNG to remove randmomness like critical hits
        makeBiasedRng(battle)
        battle.rng.bias("next", "ch", 1)
        battle.rng.bias("randInt", "miss", 0)
        battle.rng.bias("next", "secondary effect", 0)
        battle.rng.bias("randInt", "flinch", 100)

        # calculate min damage
        battle.rng.bias("randInt", "damage roll", 15)
        minDamage = move.calculateDamage(battle, attackerPokemon, defenderPokemon)

        # calculate max damage
        battle.rng.bias("randInt", "damage roll", 0)
        maxDamage = move.calculateDamage(battle, attackerPokemon, defenderPokemon)

        # TODO: Add remaining HP or anything else that's requested
        res.send(
          moveType: move.getType(battle, attackerPokemon, defenderPokemon)
          basePower: move.basePower(battle, attackerPokemon, defenderPokemon)
          minDamage: minDamage
          maxDamage: maxDamage
          defenderMaxHP: defenderPokemon.stat('hp')
        )

        return next()

@createServer = (port, done) ->
  server = restify.createServer
    name: 'pokebattle-api'
    version: '0.0.0'
  server.pre(restify.pre.sanitizePath())
  server.use(restify.acceptParser(server.acceptable))
  server.use(restify.queryParser())
  server.use(restify.bodyParser())
  server.use(restify.gzipResponse())

  server.use (req, res, next) ->
    res.charSet('utf8')
    return next()

  attachAPIEndpoints(server)

  server.listen port, ->
    console.log('%s listening at %s', server.name, server.url)
    done?()

  server
