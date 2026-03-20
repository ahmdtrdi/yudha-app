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
      main:      { x: 210, y: 390, w: 110, h: 110 },
      miniLeft:  { x: 62,  y: 342, w: 82,  h: 82  },
      miniRight: { x: 358, y: 342, w: 82,  h: 82  },
    },
    enemy: {
      main:      { x: 210, y: 115, w: 110, h: 110 },
      miniLeft:  { x: 62,  y: 163, w: 82,  h: 82  },
      miniRight: { x: 358, y: 163, w: 82,  h: 82  },
    },
  },
};

const CARDS = [
  {
    id: 0, name: 'Cannon Strike', asset: 'tiu_card.png',
    type: 'attack', attackType: 'cannon',
    damage: 350, speed: 280,
    color: '#f59e0b', glowColor: 'rgba(245,158,11,0.7)',
    category: 'numerik', label: 'Numerik',
    attackLabel: '💣 Cannon',
  },
  {
    id: 1, name: 'Wizard Bolt', asset: 'tiu_card.png',
    type: 'attack', attackType: 'wizard',
    damage: 200, speed: 600,
    color: '#a855f7', glowColor: 'rgba(168,85,247,0.7)',
    category: 'verbal', label: 'Verbal',
    attackLabel: '⚡ Wizard',
  },
  {
    id: 2, name: 'Robot Slam', asset: 'tiu_card.png',
    type: 'attack', attackType: 'robot',
    damage: 520, speed: 100,
    color: '#3eaaff', glowColor: 'rgba(62,170,255,0.7)',
    category: 'spatial', label: 'Spasial',
    attackLabel: '🤖 Robot',
  },
  {
    id: 3, name: 'TWK Heal', asset: 'twk_card.png',
    type: 'heal', attackType: 'heal',
    damage: 0, heal: CONFIG.HEAL_AMOUNT,
    speed: 260,
    color: '#22c55e', glowColor: 'rgba(34,197,94,0.7)',
    category: 'twk', label: 'TWK',
    attackLabel: '💚 Heal',
  },
];
