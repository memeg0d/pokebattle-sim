currentModal = null

PokeBattle.primus.on 'achievementsEarned', (achievements) ->
  currentModal.close()  if currentModal
  currentModal = PokeBattle.modal('modals/achievements', window: window, achievements: achievements)