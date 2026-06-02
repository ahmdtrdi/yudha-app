export const CLIENT_MATCH_EVENTS = {
  joinQueue: 'join_queue',
  cancelQueue: 'cancel_queue',
  openCard: 'open_card',
  playCard: 'play_card',
  surrender: 'surrender',
} as const;

export const SERVER_MATCH_EVENTS = {
  queueJoined: 'queue_joined',
  queueCancelled: 'queue_cancelled',
  matchFound: 'match_found',
  gameStateUpdate: 'game_state_update',
  openCardAccepted: 'open_card_accepted',
  cardActionRejected: 'card_action_rejected',
  playCardResult: 'play_card_result',
  matchResult: 'match_result',
  presenceUpdate: 'presence_update',
  error: 'error',
} as const;
