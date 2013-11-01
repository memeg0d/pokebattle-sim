{Ability} = require('./data/abilities')
{Item} = require('./data/items')
{Attachment, Status} = require('./attachment')

Priorities = {}

Priorities.endTurn = [
  # Non-order-dependent
  Attachment.Flinch
  Attachment.Roost
  Attachment.MicleBerry
  Attachment.LockOn
  Attachment.Recharge
  Attachment.Momentum
  Attachment.MeFirst
  Attachment.Charge
  Attachment.ProtectCounter
  Attachment.Protect
  Attachment.KingsShield
  Attachment.Endure
  Attachment.Pursuit
  Attachment.Present
  Attachment.MagicCoat
  Attachment.EchoedVoice
  Attachment.Rampage
  Attachment.Fling
  Attachment.DelayedAttack
  Ability.SlowStart

  # Order-dependent
  Ability.RainDish
  Ability.DrySkin
  Ability.SolarPower
  Ability.IceBody

  # Team attachments
  Attachment.FutureSight
  Attachment.DoomDesire
  Attachment.Wish

  # TODO: Fire Pledge/Grass Pledge
  Ability.ShedSkin
  Ability.Hydration
  Ability.Healer
  Item.Leftovers
  Item.BlackSludge

  Attachment.AquaRing
  Attachment.Ingrain
  Attachment.LeechSeed

  Status.Burn
  Status.Toxic
  Status.Poison
  Ability.PoisonHeal
  Attachment.Nightmare

  Attachment.Curse
  Attachment.Trap
  Attachment.Taunt
  Attachment.Encore
  Attachment.Disable
  Attachment.MagnetRise
  Attachment.Telekinesis
  # TODO: Attachment.HealBlock
  Attachment.Embargo
  Attachment.Yawn
  Attachment.PerishSong
  Attachment.Reflect
  Attachment.LightScreen
  Attachment.Screen
  # Attachment.Safeguard
  # Attachment.Mist
  # Attachment.Tailwind
  Attachment.LuckyChant
  # TODO: Pledge moves
  Attachment.Gravity
  Attachment.GravityPokemon
  Attachment.TrickRoom
  # Attachment.WonderRoom
  # Attachment.MagicRoom
  Attachment.Uproar
  Ability.SpeedBoost
  Ability.BadDreams
  Ability.Harvest
  Ability.Moody
  Item.ToxicOrb
  Item.FlameOrb
  Item.StickyBarb
  # Ability.ZenMode
]

coffee = require 'coffee-script'
path = require('path').resolve(__dirname, '../bw/priorities.coffee')
eval(coffee.compile(require('fs').readFileSync(path, 'utf8'), bare: true))
