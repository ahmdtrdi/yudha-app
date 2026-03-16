// ============================================================
//  config.js  –  Cards, towers, constants
// ============================================================

const CONFIG = {
  CANVAS_W: 420,
  CANVAS_H: 560,

  TOWER_HP: { main: 3000, mini: 1500 },
  HEAL_AMOUNT: 650,

  ENEMY_ATTACK_INTERVAL_MIN: 3.5,
  ENEMY_ATTACK_INTERVAL_MAX: 7.5,

  POWER_ROUND_EVERY: 4,   // every N questions = power round

  TOWERS: {
    player: {
      main:      { x: 210, y: 478, w: 110, h: 110 },
      miniLeft:  { x: 62,  y: 413, w: 82,  h: 82  },
      miniRight: { x: 358, y: 413, w: 82,  h: 82  },
    },
    enemy: {
      main:      { x: 210, y: 82,  w: 110, h: 110 },
      miniLeft:  { x: 62,  y: 148, w: 82,  h: 82  },
      miniRight: { x: 358, y: 148, w: 82,  h: 82  },
    },
  },
};

const CARDS = [
  {
    id: 0, name: 'TIU Strike', asset: 'tiu_card.png',
    type: 'attack', damage: 350, speed: 280,
    color: '#00c3ff', glowColor: 'rgba(0,195,255,0.7)',
    category: 'math', label: 'Math',
  },
  {
    id: 1, name: 'TIU Strike', asset: 'tiu_card.png',
    type: 'attack', damage: 360, speed: 275,
    color: '#a855f7', glowColor: 'rgba(168,85,247,0.7)',
    category: 'science', label: 'Science',
  },
  {
    id: 2, name: 'TIU Strike', asset: 'tiu_card.png',
    type: 'attack', damage: 340, speed: 295,
    color: '#f59e0b', glowColor: 'rgba(245,158,11,0.7)',
    category: 'logic', label: 'Logic',
  },
  {
    id: 3, name: 'TWK Heal', asset: 'twk_card.png',
    type: 'heal', damage: 0, heal: CONFIG.HEAL_AMOUNT,
    speed: 260,
    color: '#22c55e', glowColor: 'rgba(34,197,94,0.7)',
    category: 'general', label: 'General',
  },
];
