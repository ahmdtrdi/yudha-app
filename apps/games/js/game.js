// ============================================================
//  game.js  –  Game loop, state, bot AI, multiplayer, VFX
// ============================================================

const Game = (() => {

  const canvas = document.getElementById('gameCanvas');
  const ctx    = canvas.getContext('2d');

  // ── DPR-aware canvas setup ────────────────────────────────
  function setupCanvas() {
    const dpr = window.devicePixelRatio || 1;
    canvas.width  = CONFIG.CANVAS_W * dpr;
    canvas.height = CONFIG.CANVAS_H * dpr;
    ctx.scale(dpr, dpr);
  }

  // ── Preload images ────────────────────────────────────────
  const IMG = {};
  [
    'attack_side_blue','attack_side_red','attack_stright_blue',
    'impact_explosion',
    'blue_maintower','blue_maintower_destroyed',
    'blue_minitower','blue_minitower_destroyed',
    'red_maintower','red_maintower_destroyed',
    'red_minitower','red_minitower_destroyed',
  ].forEach(k => {
    const i = new Image();
    i.src = `assets/${k}.png`;
    IMG[k] = i;
  });

  // ── Game state ────────────────────────────────────────────
  let state       = {};
  let pendingCard = null;
  let lastTime    = 0;
  let enemyTimer  = 0;
  let nextEnemyAt = 4;
  let animId      = null;
  let totalTime   = 0;
  let gameMode    = 'bot'; // 'bot' | 'multiplayer'

  // Combo & stats
  let playerStreak  = 0;
  let maxStreak     = 0;
  let questTotal    = 0;
  let questCorrect  = 0;
  let questionCount = 0; // for power round trigger

  // VFX
  let screenShake  = 0;
  let particles    = [];
  let healOrbs     = [];
  let cloudShadows = [];
  let riverOffset  = 0;

  // ── Reset ─────────────────────────────────────────────────
  function resetState() {
    state = {
      playerHp: { main: CONFIG.TOWER_HP.main, miniLeft: CONFIG.TOWER_HP.mini, miniRight: CONFIG.TOWER_HP.mini },
      enemyHp:  { main: CONFIG.TOWER_HP.main, miniLeft: CONFIG.TOWER_HP.mini, miniRight: CONFIG.TOWER_HP.mini },
      towerDestroyed: {
        player: { main: false, miniLeft: false, miniRight: false },
        enemy:  { main: false, miniLeft: false, miniRight: false },
      },
      projectiles: [],
      explosions:  [],
      gameOver:    false,
      paused:      false,
    };
    enemyTimer    = 0;
    nextEnemyAt   = randBetween(CONFIG.ENEMY_ATTACK_INTERVAL_MIN, CONFIG.ENEMY_ATTACK_INTERVAL_MAX);
    totalTime     = 0;
    screenShake   = 0;
    particles     = [];
    healOrbs      = [];
    cloudShadows  = initClouds();
    playerStreak  = 0;
    maxStreak     = 0;
    questTotal    = 0;
    questCorrect  = 0;
    questionCount = 0;
    UI.updateStreak(0);
    UI.hideCardBoosts();
    spawnAmbientParticles();
  }

  // ── Cloud init ────────────────────────────────────────────
  function initClouds() {
    return Array.from({ length: 3 }, (_, i) => ({
      x: i * 180 - 60, y: randBetween(20, 160),
      w: randBetween(120, 220), h: randBetween(40, 70),
      speed: randBetween(8, 18), alpha: randBetween(0.05, 0.12),
    }));
  }

  // ── Ambient particles ─────────────────────────────────────
  function spawnAmbientParticles() {
    for (let i = 0; i < 22; i++) particles.push(makeParticle(true));
  }
  function makeParticle(randomY = false) {
    return {
      x: randBetween(10, CONFIG.CANVAS_W - 10),
      y: randomY ? randBetween(0, CONFIG.CANVAS_H) : CONFIG.CANVAS_H + 10,
      vx: randBetween(-18, 18), vy: randBetween(-30, -12),
      size: randBetween(2, 5), alpha: randBetween(0.3, 0.9),
      life: 1, decay: randBetween(0.004, 0.012),
      hue: Math.random() < 0.5 ? 180 : randBetween(100, 280),
    };
  }

  // ── Target picking ────────────────────────────────────────
  function pickTarget(attackerSide) {
    const def  = attackerSide === 'enemy' ? 'player' : 'enemy';
    const dest = state.towerDestroyed[def];
    const minis = ['miniLeft','miniRight'].filter(w => !dest[w]);
    return minis.length ? minis[Math.floor(Math.random() * minis.length)] : 'main';
  }
  function pickHealTarget() {
    const hpObj = state.playerHp;
    const dest  = state.towerDestroyed.player;
    let worst = null, worstHp = Infinity;
    for (const w of ['miniLeft','miniRight','main']) {
      if (!dest[w] && hpObj[w] < worstHp) { worstHp = hpObj[w]; worst = w; }
    }
    return worst;
  }

  // ── Combo multiplier ──────────────────────────────────────
  function getComboMultiplier() {
    if (playerStreak < 2) return 1.0;
    return Math.min(1.0 + 0.2 * (playerStreak - 1), 2.0);
  }

  // ── Power round ───────────────────────────────────────────
  function checkPowerRound() {
    if (questionCount > 0 && questionCount % CONFIG.POWER_ROUND_EVERY === 0) {
      UI.showPowerRound();
      return true;
    }
    return false;
  }

  // ── Spawn projectile ──────────────────────────────────────
  function spawnProjectile(fromSide, targetWhich, card) {
    const from   = { ...CONFIG.TOWERS[fromSide].main };
    const toSide = fromSide === 'player' ? 'enemy' : 'player';
    const to     = { ...CONFIG.TOWERS[toSide][targetWhich] };
    const dx = to.x - from.x, dy = to.y - from.y;
    const len = Math.sqrt(dx*dx + dy*dy) || 1;

    state.projectiles.push({
      x: from.x, y: from.y,
      vx: (dx/len) * card.speed,
      vy: (dy/len) * card.speed,
      target: targetWhich, toSide,
      damage: card.damage,
      radius: 14,
      color: card.color, glow: card.glowColor,
      trail: [], fromSide,
      imgKey: fromSide === 'player'
        ? (card.id === 1 ? 'attack_stright_blue' : 'attack_side_blue')
        : 'attack_side_red',
    });
  }

  // ── Spawn heal orb ────────────────────────────────────────
  function spawnHealOrb(targetWhich) {
    const from = { ...CONFIG.TOWERS.player.main };
    const to   = { ...CONFIG.TOWERS.player[targetWhich] };
    const dx = to.x - from.x, dy = to.y - from.y;
    const len = Math.sqrt(dx*dx + dy*dy) || 1;
    healOrbs.push({
      x: from.x, y: from.y,
      vx: (dx/len) * 220, vy: (dy/len) * 220,
      target: targetWhich, trail: [],
    });
  }

  // ── Explosion ─────────────────────────────────────────────
  function spawnExplosion(x, y, big = false) {
    state.explosions.push({ x, y, life: 1.0, big });
    if (big) screenShake = 0.4;
    else     screenShake = Math.max(screenShake, 0.18);

    const count = big ? 16 : 8;
    for (let i = 0; i < count; i++) {
      const ang = (i / count) * Math.PI * 2;
      const spd = randBetween(45, 140);
      particles.push({
        x, y,
        vx: Math.cos(ang) * spd, vy: Math.sin(ang) * spd,
        size: randBetween(3, big ? 10 : 7),
        alpha: 1, life: 1,
        decay: randBetween(0.03, 0.06),
        hue: big ? 30 : 200,
      });
    }
  }

  // ── Damage tower ──────────────────────────────────────────
  function damageTower(side, which, amount) {
    const key = `${side}Hp`;
    state[key][which] = Math.max(0, state[key][which] - amount);
    const maxHp = which === 'main' ? CONFIG.TOWER_HP.main : CONFIG.TOWER_HP.mini;
    UI.updateTowerHp(side, which, state[key][which], maxHp);
    UI.floatDamage(
      CONFIG.TOWERS[side][which].x - 24,
      CONFIG.TOWERS[side][which].y - 55,
      '-' + amount, side === 'enemy' ? 'dmg-enemy' : 'dmg-player'
    );
    if (state[key][which] <= 0 && !state.towerDestroyed[side][which]) {
      state.towerDestroyed[side][which] = true;
      UI.setTowerDestroyed(side, which);
      spawnExplosion(CONFIG.TOWERS[side][which].x, CONFIG.TOWERS[side][which].y, true);
      if (side === 'enemy' && state.towerDestroyed.enemy.main) endGame(true);
      if (side === 'player' && state.towerDestroyed.player.main) endGame(false);
    }
  }

  // ── Heal tower ────────────────────────────────────────────
  function healTower(which, amount) {
    const maxHp = which === 'main' ? CONFIG.TOWER_HP.main : CONFIG.TOWER_HP.mini;
    state.playerHp[which] = Math.min(maxHp, state.playerHp[which] + amount);
    UI.updateTowerHp('player', which, state.playerHp[which], maxHp);
    UI.floatDamage(
      CONFIG.TOWERS.player[which].x - 24,
      CONFIG.TOWERS.player[which].y - 55,
      '+' + amount, 'dmg-heal'
    );
    for (let i = 0; i < 12; i++) {
      const ang = Math.random() * Math.PI * 2;
      particles.push({
        x: CONFIG.TOWERS.player[which].x, y: CONFIG.TOWERS.player[which].y,
        vx: Math.cos(ang) * randBetween(30, 95), vy: Math.sin(ang) * randBetween(30, 95),
        size: randBetween(3, 8), alpha: 1, life: 1,
        decay: randBetween(0.025, 0.055), hue: 120,
      });
    }
  }

  // ── Card click ────────────────────────────────────────────
  function onCardClick(card) {
    if (state.paused || state.gameOver) return;
    state.paused = true;
    pendingCard  = card;

    questionCount++;
    questTotal++;
    const isPower = checkPowerRound();

    const question = getRandomQuestion(card.category);
    UI.showQuestion(question, card, (correct, timeLeft) => {
      state.paused = false;
      pendingCard  = null;

      if (!correct) {
        playerStreak = 0;
        questTotal++;
        UI.updateStreak(0);
        UI.hideCardBoosts();
        UI.toastPlayerWrong();
        return;
      }

      // Track stats
      questCorrect++;
      playerStreak++;
      if (playerStreak > maxStreak) maxStreak = playerStreak;
      UI.updateStreak(playerStreak);

      if (playerStreak >= 2) {
        UI.showCombo(playerStreak);
        // Show boost badge on attack cards
        CARDS.filter(c => c.type === 'attack').forEach(c => UI.showCardBoost(c.id, getComboMultiplier()));
      } else {
        UI.hideCardBoosts();
      }

      // Calculate damage with combo & power round
      const combo     = getComboMultiplier();
      let   damage    = Math.round((card.damage || 0) * combo);
      if (isPower && timeLeft > 5) damage = Math.round(damage * 2);

      if (card.type === 'heal') {
        UI.toastHeal();
        const target = pickHealTarget();
        if (target) spawnHealOrb(target);
      } else {
        UI.toastPlayerCorrect();
        const target = pickTarget('player');
        const attackCard = { ...card, damage };
        spawnProjectile('player', target, attackCard);

        // Show combo float
        if (combo > 1) {
          UI.floatDamage(
            CONFIG.TOWERS.enemy.main.x - 30,
            CONFIG.TOWERS.enemy.main.y - 80,
            `×${combo.toFixed(1)}`, 'dmg-combo'
          );
        }

        // Multiplayer: send attack to opponent
        if (gameMode === 'multiplayer' && Multiplayer.isConnected()) {
          Multiplayer.send({
            type: 'attack', target, damage,
            color: card.color, glowColor: card.glowColor,
            speed: card.speed, cardId: card.id,
          });
        }
      }
    }, () => {
      // Timeout
      playerStreak = 0;
      UI.updateStreak(0);
      UI.hideCardBoosts();
      state.paused = false;
      pendingCard  = null;
    }, isPower);
  }

  UI._onCancel = () => {
    state.paused = false;
    pendingCard  = null;
  };

  // ── Bot AI ────────────────────────────────────────────────
  function enemyAttack() {
    const attackCards = CARDS.filter(c => c.type === 'attack');
    const card   = attackCards[Math.floor(Math.random() * attackCards.length)];
    const target = pickTarget('enemy');
    const cardIndex = Math.floor(Math.random() * 4);

    // Notification + flash
    UI.toastEnemyAttack(card.label);
    UI.flashEnemyCard(cardIndex);

    spawnProjectile('enemy', target, {
      ...card,
      damage: Math.floor(card.damage * 0.72),
      speed:  card.speed * 0.88,
      color:  '#ff4444',
      glowColor: 'rgba(255,60,60,0.7)',
    });
  }

  // ── Multiplayer: receive attack ───────────────────────────
  function onMultiplayerMessage(msg) {
    if (state.gameOver) return;

    if (msg.type === 'attack') {
      // Opponent attacked ME → enemy fires at my player towers
      UI.toastEnemyAttack('their card');
      UI.flashEnemyCard(Math.floor(Math.random() * 4));

      const target  = pickTarget('enemy'); // pick one of my towers
      spawnProjectile('enemy', target, {
        id: msg.cardId || 0,
        damage: msg.damage,
        speed:  msg.speed || 280,
        color:  msg.color || '#ff4444',
        glowColor: msg.glowColor || 'rgba(255,60,60,0.7)',
      });
    } else if (msg.type === 'game_over') {
      // Opponent says I lost (they destroyed my last tower from their perspective)
      endGame(false);
    }
  }

  // ── Draw: field ───────────────────────────────────────────
  function drawField(dt) {
    riverOffset = (riverOffset + dt * 22) % 80;
    const W = CONFIG.CANVAS_W, H = CONFIG.CANVAS_H;
    const MID = H / 2, t = totalTime;

    // Grass
    ctx.fillStyle = '#4b9130';
    ctx.fillRect(0, 0, W, H);
    for (let gx = 0; gx < W; gx += 28) {
      for (let gy = 0; gy < H; gy += 28) {
        if ((Math.floor(gx/28) + Math.floor(gy/28)) % 2 === 0) {
          ctx.fillStyle = 'rgba(255,255,255,0.04)';
          ctx.fillRect(gx, gy, 28, 28);
        }
      }
    }

    // Cloud shadows
    cloudShadows.forEach(c => {
      ctx.save();
      ctx.globalAlpha = c.alpha;
      const gr = ctx.createRadialGradient(c.x+c.w/2, c.y+c.h/2, 0, c.x+c.w/2, c.y+c.h/2, c.w/2);
      gr.addColorStop(0, 'rgba(0,0,0,0.5)'); gr.addColorStop(1, 'rgba(0,0,0,0)');
      ctx.fillStyle = gr;
      ctx.beginPath(); ctx.ellipse(c.x+c.w/2, c.y+c.h/2, c.w/2, c.h/2, 0, 0, Math.PI*2); ctx.fill();
      ctx.restore();
    });

    // Dirt paths
    function rr(x, y, w, h, r = 6) {
      ctx.beginPath(); ctx.roundRect(x, y, w, h, r); ctx.fill();
    }
    ctx.fillStyle = '#c8a05a'; rr(W/2-46, 0, 92, H, 0);
    ctx.fillStyle = 'rgba(0,0,0,0.1)'; rr(W/2-46, 0, 5, H, 0); rr(W/2+41, 0, 5, H, 0);
    ctx.fillStyle = '#c8a05a'; rr(0, MID-34, W, 68, 0);
    ctx.fillStyle = 'rgba(0,0,0,0.1)'; rr(0, MID-34, W, 5, 0); rr(0, MID+29, W, 5, 0);

    // Stone pads
    const pads = [
      {x:18, y:112, w:84, h:72}, {x:318, y:112, w:84, h:72},
      {x:18, y:376, w:84, h:72}, {x:318, y:376, w:84, h:72},
      {x:W/2-58, y:26, w:116, h:112}, {x:W/2-58, y:422, w:116, h:112},
    ];
    ctx.fillStyle = '#9e8c6a';
    pads.forEach(p => rr(p.x, p.y, p.w, p.h, 8));
    ctx.strokeStyle = 'rgba(0,0,0,0.1)'; ctx.lineWidth = 1;
    pads.forEach(p => {
      for (let px = p.x; px < p.x+p.w; px += 18) { ctx.beginPath(); ctx.moveTo(px,p.y); ctx.lineTo(px,p.y+p.h); ctx.stroke(); }
      for (let py = p.y; py < p.y+p.h; py += 18) { ctx.beginPath(); ctx.moveTo(p.x,py); ctx.lineTo(p.x+p.w,py); ctx.stroke(); }
    });

    // Animated river
    ctx.save();
    const rGrad = ctx.createLinearGradient(0, MID-26, 0, MID+26);
    rGrad.addColorStop(0, '#0ab8d8'); rGrad.addColorStop(0.35, '#18e8ff');
    rGrad.addColorStop(0.65, '#18e8ff'); rGrad.addColorStop(1, '#0ab8d8');
    ctx.fillStyle = rGrad;
    ctx.beginPath(); ctx.moveTo(0, MID-26);
    for (let x = 0; x <= W; x += 3) ctx.lineTo(x, MID-26 + Math.sin((x+riverOffset)*0.07)*5);
    ctx.lineTo(W, MID+26);
    for (let x = W; x >= 0; x -= 3) ctx.lineTo(x, MID+26 + Math.sin((x+riverOffset*0.8)*0.09)*4);
    ctx.closePath(); ctx.fill();
    for (let i = 0; i < 5; i++) {
      const sx = ((i*90 + riverOffset*3.5) % (W+60)) - 30;
      const pulse = 0.3 + 0.2 * Math.sin(t*3+i);
      ctx.globalAlpha = pulse; ctx.fillStyle = '#ffffff';
      ctx.beginPath(); ctx.ellipse(sx, MID+Math.sin(i*1.3)*7, 22, 5, -0.2, 0, Math.PI*2); ctx.fill();
    }
    ctx.globalAlpha = 0.18; ctx.strokeStyle = '#ffffff'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.moveTo(0, MID-26);
    for (let x = 0; x <= W; x += 3) ctx.lineTo(x, MID-26 + Math.sin((x+riverOffset)*0.07)*5);
    ctx.stroke();
    ctx.globalAlpha = 1; ctx.restore();

    // Bridge stones
    ctx.save();
    ctx.shadowBlur = 6; ctx.shadowColor = 'rgba(0,0,0,0.35)';
    ctx.fillStyle = '#7a6a4a';
    [[W/2-40,MID-22],[W/2+16,MID-22],[W/2-40,MID+4],[W/2+16,MID+4]].forEach(([bx,by]) => {
      ctx.beginPath(); ctx.roundRect(bx, by, 24, 18, 3); ctx.fill();
    });
    const pp = 1 + 0.12*Math.sin(t*2.5);
    ctx.shadowBlur = 14*pp; ctx.shadowColor = '#ffcc44'; ctx.fillStyle = '#e8b840';
    [[W/2-46,MID-8],[W/2+46,MID-8]].forEach(([bx,by]) => {
      ctx.beginPath(); ctx.arc(bx, by, 7*pp, 0, Math.PI*2); ctx.fill();
    });
    ctx.restore();

    // Side walls
    ctx.fillStyle = 'rgba(40,26,10,0.25)';
    ctx.fillRect(0, 0, 18, H); ctx.fillRect(W-18, 0, 18, H);

    // Torches
    const flicker = 0.85 + 0.15*Math.sin(t*12+1);
    drawTorch(18, MID-62, '#ffaa00', flicker);
    drawTorch(18, MID+62, '#ffaa00', flicker*0.9);
    drawTorch(W-18, MID-62, '#ffaa00', flicker*0.95);
    drawTorch(W-18, MID+62, '#ffaa00', flicker);

    // Game mode indicator (small label in arena)
    if (gameMode === 'multiplayer') {
      ctx.save();
      ctx.fillStyle = 'rgba(147,51,234,0.7)';
      ctx.beginPath(); ctx.roundRect(W/2-28, 4, 56, 14, 7); ctx.fill();
      ctx.fillStyle = 'white'; ctx.font = '700 9px Nunito,sans-serif';
      ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
      ctx.fillText('🌐 VS PLAYER', W/2, 11);
      ctx.restore();
    }
  }

  function drawTorch(x, y, color, flicker = 1) {
    ctx.save();
    ctx.shadowBlur = 22*flicker; ctx.shadowColor = color;
    ctx.fillStyle = color; ctx.globalAlpha = 0.9*flicker;
    ctx.beginPath(); ctx.arc(x, y, 5*flicker, 0, Math.PI*2); ctx.fill();
    ctx.globalAlpha = 0.22*flicker;
    ctx.beginPath(); ctx.arc(x, y, 16*flicker, 0, Math.PI*2); ctx.fill();
    ctx.globalAlpha = 1; ctx.restore();
  }

  // ── Draw particles ────────────────────────────────────────
  function drawParticles(dt) {
    if (Math.random() < dt * 4) particles.push(makeParticle(false));
    for (let i = particles.length - 1; i >= 0; i--) {
      const p = particles[i];
      p.x += p.vx * dt; p.y += p.vy * dt;
      p.vy -= 15 * dt; p.life -= p.decay;
      if (p.life <= 0) { particles.splice(i, 1); continue; }
      ctx.save();
      ctx.globalAlpha = p.alpha * p.life;
      ctx.fillStyle = `hsl(${p.hue},100%,70%)`;
      ctx.shadowBlur = 6; ctx.shadowColor = `hsl(${p.hue},100%,70%)`;
      ctx.beginPath(); ctx.arc(p.x, p.y, p.size * p.life, 0, Math.PI*2); ctx.fill();
      ctx.restore();
    }
  }

  // ── Draw heal orbs ────────────────────────────────────────
  function drawHealOrbs(dt) {
    for (let i = healOrbs.length - 1; i >= 0; i--) {
      const orb = healOrbs[i];
      orb.x += orb.vx * dt; orb.y += orb.vy * dt;
      orb.trail.push({ x: orb.x, y: orb.y });
      if (orb.trail.length > 10) orb.trail.shift();

      const to = CONFIG.TOWERS.player[orb.target];
      const dx = orb.x - to.x, dy = orb.y - to.y;
      if (Math.sqrt(dx*dx+dy*dy) < 30) {
        healOrbs.splice(i, 1);
        healTower(orb.target, CONFIG.HEAL_AMOUNT);
        continue;
      }

      orb.trail.forEach((pt, ti) => {
        ctx.save();
        ctx.globalAlpha = (ti/orb.trail.length) * 0.5;
        ctx.fillStyle = '#4ade80'; ctx.shadowBlur = 8; ctx.shadowColor = '#22c55e';
        ctx.beginPath(); ctx.arc(pt.x, pt.y, 5*(ti/orb.trail.length), 0, Math.PI*2); ctx.fill();
        ctx.restore();
      });
      ctx.save();
      ctx.shadowBlur = 26; ctx.shadowColor = '#22c55e';
      ctx.fillStyle = '#4ade80'; ctx.globalAlpha = 0.95;
      ctx.beginPath(); ctx.arc(orb.x, orb.y, 12, 0, Math.PI*2); ctx.fill();
      ctx.fillStyle = '#bbf7d0'; ctx.globalAlpha = 0.7;
      ctx.beginPath(); ctx.arc(orb.x-4, orb.y-4, 4, 0, Math.PI*2); ctx.fill();
      ctx.restore();
    }
  }

  // ── Draw projectiles ──────────────────────────────────────
  function drawProjectiles(dt) {
    state.projectiles.forEach(p => {
      p.trail.push({ x: p.x, y: p.y });
      if (p.trail.length > 9) p.trail.shift();

      p.trail.forEach((pt, i) => {
        ctx.save();
        ctx.globalAlpha = (i/p.trail.length) * 0.45;
        ctx.shadowBlur = 10; ctx.shadowColor = p.glow;
        ctx.fillStyle = p.color;
        ctx.beginPath(); ctx.arc(pt.x, pt.y, p.radius*0.6*(i/p.trail.length), 0, Math.PI*2); ctx.fill();
        ctx.restore();
      });

      ctx.save();
      ctx.shadowBlur = 26; ctx.shadowColor = p.glow;
      const img = IMG[p.imgKey];
      if (img && img.complete && img.naturalWidth > 0) {
        const r = p.radius * 2.6;
        const angle = Math.atan2(p.vy, p.vx);
        ctx.translate(p.x, p.y); ctx.rotate(angle);
        ctx.drawImage(img, -r, -r*0.6, r*2, r*1.2);
      } else {
        ctx.fillStyle = p.color;
        ctx.beginPath(); ctx.arc(p.x, p.y, p.radius, 0, Math.PI*2); ctx.fill();
      }
      ctx.restore();
    });
  }

  // ── Draw explosions ───────────────────────────────────────
  function drawExplosions(dt) {
    for (let i = state.explosions.length - 1; i >= 0; i--) {
      const ex = state.explosions[i];
      ex.life -= dt * 2;
      if (ex.life <= 0) { state.explosions.splice(i, 1); continue; }
      const scale = (1 - ex.life) * (ex.big ? 90 : 55) + 12;
      const img = IMG['impact_explosion'];
      ctx.save();
      ctx.globalAlpha = ex.life;
      if (img && img.complete) {
        ctx.drawImage(img, ex.x-scale, ex.y-scale, scale*2, scale*2);
      } else {
        ctx.fillStyle = ex.big ? `rgba(255,120,0,${ex.life})` : `rgba(0,200,255,${ex.life})`;
        ctx.beginPath(); ctx.arc(ex.x, ex.y, scale, 0, Math.PI*2); ctx.fill();
      }
      ctx.restore();
    }
  }

  // ── Main loop ─────────────────────────────────────────────
  function loop(timestamp) {
    const dt = Math.min((timestamp - lastTime) / 1000, 0.1);
    lastTime  = timestamp;
    totalTime += dt;

    if (!state.paused && !state.gameOver) {
      // Bot AI
      if (gameMode === 'bot') {
        enemyTimer += dt;
        if (enemyTimer >= nextEnemyAt) {
          enemyTimer  = 0;
          nextEnemyAt = randBetween(CONFIG.ENEMY_ATTACK_INTERVAL_MIN, CONFIG.ENEMY_ATTACK_INTERVAL_MAX);
          enemyAttack();
        }
      }

      // Cloud drift
      cloudShadows.forEach(c => {
        c.x += c.speed * dt;
        if (c.x > CONFIG.CANVAS_W + 100) c.x = -c.w - 20;
      });

      // Move projectiles
      for (let i = state.projectiles.length - 1; i >= 0; i--) {
        const p = state.projectiles[i];
        p.x += p.vx * dt; p.y += p.vy * dt;
        const tgt = CONFIG.TOWERS[p.toSide][p.target];
        const dx = p.x - tgt.x, dy = p.y - tgt.y;
        if (Math.sqrt(dx*dx+dy*dy) < tgt.w / 2) {
          state.projectiles.splice(i, 1);
          spawnExplosion(tgt.x, tgt.y);
          damageTower(p.toSide, p.target, p.damage);
        }
      }
    }

    // Screen shake
    ctx.save();
    if (screenShake > 0) {
      screenShake -= dt * 3;
      const sh = screenShake * 8;
      ctx.translate(randBetween(-sh, sh), randBetween(-sh, sh));
    }

    ctx.clearRect(-10, -10, CONFIG.CANVAS_W+20, CONFIG.CANVAS_H+20);
    drawField(dt);
    drawParticles(dt);
    drawProjectiles(dt);
    drawHealOrbs(dt);
    drawExplosions(dt);
    ctx.restore();

    if (!state.gameOver) animId = requestAnimationFrame(loop);
  }

  // ── Game over ─────────────────────────────────────────────
  function endGame(won) {
    if (state.gameOver) return;
    state.gameOver = true;

    // Send defeat message to opponent
    if (won && gameMode === 'multiplayer' && Multiplayer.isConnected()) {
      Multiplayer.send({ type: 'game_over' });
    }

    const stats = {
      correct:  questCorrect,
      total:    questTotal,
      maxStreak: maxStreak,
      accuracy: questTotal > 0 ? (questCorrect / questTotal * 100) : 0,
    };

    setTimeout(() => {
      UI.showGameOver(won, stats,
        () => init(gameMode),      // restart
        () => goToMenu()           // menu
      );
    }, 700);
  }

  // ── Go to menu ────────────────────────────────────────────
  function goToMenu() {
    if (animId) { cancelAnimationFrame(animId); animId = null; }
    try { Multiplayer.close(); } catch(e) {}
    UI.showScreen('menu');
  }

  // ── Reset towers UI ───────────────────────────────────────
  function resetTowersUI() {
    const colorMap = { player: 'blue', enemy: 'red' };
    ['player','enemy'].forEach(side => {
      ['main','miniLeft','miniRight'].forEach(which => {
        const maxHp = which === 'main' ? CONFIG.TOWER_HP.main : CONFIG.TOWER_HP.mini;
        UI.updateTowerHp(side, which, maxHp, maxHp);
        const img = document.getElementById(`tower-img-${side}-${which}`);
        if (img) {
          img.src = `assets/${colorMap[side]}_${which === 'main' ? 'maintower' : 'minitower'}.png`;
          img.classList.remove('destroyed', 'hit-flash');
        }
      });
    });
  }

  // ── Init ──────────────────────────────────────────────────
  function init(mode = 'bot') {
    if (animId) cancelAnimationFrame(animId);
    gameMode = mode;
    setupCanvas();
    resetState();
    resetTowersUI();
    UI.buildDeck(CARDS, onCardClick);
    UI.showScreen('game');

    // Set labels
    const enemyLabel = document.getElementById('enemy-label');
    if (enemyLabel) enemyLabel.textContent = (gameMode === 'bot') ? '🤖 Bot' : '👤 Opponent';
    const playerLabel = document.getElementById('player-label');
    if (playerLabel) playerLabel.textContent = '👤 You';

    lastTime = performance.now();
    animId = requestAnimationFrame(loop);
  }

  // Public: init multiplayer game and set up message handler
  function initMultiplayer() {
    // Override Multiplayer message handler for in-game
  }

  return { init, endGame, onMultiplayerMessage, goToMenu };
})();

function randBetween(a, b) { return a + Math.random() * (b - a); }

// ============================================================
//  Menu & Screen Navigation
// ============================================================

window.addEventListener('load', () => {
  UI.showScreen('menu');
  UI.initMenuParticles();

  // ── VS Bot ──
  document.getElementById('btn-vs-bot').addEventListener('click', () => {
    try { Multiplayer.close(); } catch(e) {}
    Game.init('bot');
  });

  // ── VS Player ──
  document.getElementById('btn-vs-player').addEventListener('click', () => {
    UI.showScreen('mp');
  });

  // ── Back from MP screen ──
  document.getElementById('btn-back-mp').addEventListener('click', () => {
    try { Multiplayer.close(); } catch(e) {}
    UI.showScreen('menu');
  });

  // ── Create Room ──
  document.getElementById('btn-create-room').addEventListener('click', () => {
    const btn = document.getElementById('btn-create-room');
    btn.disabled = true; btn.textContent = 'Connecting…';

    Multiplayer.createRoom(
      (code) => {
        // Got code
        document.getElementById('room-code-wrap').hidden = false;
        document.getElementById('room-code-text').textContent = code;
        btn.textContent = 'Waiting…';
      },
      () => {
        // Opponent connected
        UI.toast('🟢', 'Opponent connected! Starting game…', 'correct', 2500);
        setTimeout(() => {
          Game.init('multiplayer');
          // Set up message handler
          Multiplayer.send({ type: 'game_start' });
        }, 1200);
      },
      (msg) => {
        if (msg.type === 'game_start') { /* host already started */ }
        else Game.onMultiplayerMessage(msg);
      },
      () => {
        UI.toastOpponentDisconnected();
        if (!document.getElementById('game-wrapper').hidden) {
          // In game — opponent left
          setTimeout(() => Game.goToMenu(), 2000);
        }
      }
    );
  });

  // ── Copy room code ──
  document.getElementById('room-code-text').addEventListener('click', () => {
    const code = document.getElementById('room-code-text').textContent;
    navigator.clipboard.writeText(code).catch(() => {});
    UI.toast('📋', 'Code copied!', 'info', 1500);
  });

  // ── Join Room ──
  document.getElementById('btn-join-room').addEventListener('click', () => {
    const code = document.getElementById('join-code-input').value.trim().toUpperCase();
    if (code.length < 4) {
      document.getElementById('join-status').textContent = '❌ Please enter a valid code.';
      return;
    }

    const btn = document.getElementById('btn-join-room');
    btn.disabled = true; btn.textContent = 'Connecting…';
    document.getElementById('join-status').innerHTML = '<span class="sdot"></span> Connecting…';

    Multiplayer.joinRoom(
      code,
      () => {
        // Connected
        document.getElementById('join-status').textContent = '✅ Connected! Starting…';
        UI.toast('🟢', 'Connected! Starting game…', 'correct', 2000);
        Multiplayer.send({ type: 'game_start' });
        setTimeout(() => Game.init('multiplayer'), 1200);
      },
      (msg) => {
        if (msg.type === 'game_start') { /* already started */ }
        else Game.onMultiplayerMessage(msg);
      },
      () => {
        UI.toastOpponentDisconnected();
        if (!document.getElementById('game-wrapper').hidden) {
          setTimeout(() => Game.goToMenu(), 2000);
        }
      }
    );
  });

  // Allow pressing Enter in join input
  document.getElementById('join-code-input').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') document.getElementById('btn-join-room').click();
  });
  document.getElementById('join-code-input').addEventListener('input', (e) => {
    e.target.value = e.target.value.toUpperCase();
  });
});
