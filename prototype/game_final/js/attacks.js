// ============================================================
//  attacks.js  –  Attack Animation System
//  Three attack types: ROBOT (heavy/slow), CANNON (balanced),
//  WIZARD (fast/lightning)
// ============================================================

const AttackAnim = (() => {

  let robots    = [];
  let cannons   = [];
  let wizards   = [];
  let _damage   = null;   // callback: (side, which, dmg) => void
  let _particle = null;   // callback: (particleObj) => void
  let _shake    = null;   // callback: (amount) => void

  function init(damageCb, particleCb, shakeCb) {
    _damage   = damageCb;
    _particle = particleCb;
    _shake    = shakeCb;
  }

  function reset() { robots = []; cannons = []; wizards = []; }

  function rb(a, b) { return a + Math.random() * (b - a); }

  // ── Burst particles helper ────────────────────────────────
  function burst(x, y, count, hue, speedMin, speedMax, sizeMin, sizeMax, decayMin, decayMax) {
    if (!_particle) return;
    for (let i = 0; i < count; i++) {
      const ang = (i / count) * Math.PI * 2 + rb(-0.3, 0.3);
      const spd = rb(speedMin, speedMax);
      _particle({
        x, y,
        vx: Math.cos(ang) * spd, vy: Math.sin(ang) * spd,
        size:  rb(sizeMin, sizeMax),
        alpha: 1, life: 1,
        decay: rb(decayMin, decayMax),
        hue,
      });
    }
  }

  // ════════════════════════════════════════════════════════
  //  ROBOT  –  heavy slam, 4 s walk
  // ════════════════════════════════════════════════════════
  function spawnRobot(fromSide, toSide, targetWhich, damage) {
    const sx  = CONFIG.CANVAS_W / 2;
    const sy  = fromSide === 'enemy' ? 88 : CONFIG.CANVAS_H - 88;
    const tgt = CONFIG.TOWERS[toSide][targetWhich];
    const ty  = fromSide === 'enemy' ? tgt.y + 20 : tgt.y + 10;
    robots.push({
      x: sx, y: sy,
      startY: sy,
      tx: tgt.x, ty,
      toSide, targetWhich, damage,
      fromSide,
      phase: 'walk',
      t: 0, stepT: 0, leg: 0, slamT: 0,
      hit: false, alpha: 1,
    });
  }

  function updateRobots(dt) {
    const WALK = 4.0;
    for (let i = robots.length - 1; i >= 0; i--) {
      const r = robots[i];
      if (r.phase === 'walk') {
        r.t += dt;
        const prog = Math.min(r.t / WALK, 1);
        const ease = prog < 0.5 ? 2*prog*prog : -1+(4-2*prog)*prog;
        r.x = CONFIG.CANVAS_W / 2 + (r.tx - CONFIG.CANVAS_W / 2) * ease;
        r.y = r.startY + (r.ty - r.startY) * ease;

        r.stepT += dt;
        if (r.stepT >= 0.38) {
          r.stepT = 0; r.leg ^= 1;
          if (_shake) _shake(0.06);
        }
        if (prog >= 1) { r.phase = 'windup'; r.slamT = 0; }

      } else if (r.phase === 'windup') {
        r.slamT += dt;
        if (r.slamT >= 0.35) { r.phase = 'slam'; r.slamT = 0; }

      } else if (r.phase === 'slam') {
        r.slamT += dt;
        if (!r.hit && r.slamT >= 0.12) {
          r.hit = true;
          if (_shake) _shake(0.55);
          if (_damage) _damage(r.toSide, r.targetWhich, r.damage);
          burst(r.tx, r.ty, 28, 30, 55, 220, 4, 13, 0.018, 0.05);
          burst(r.tx, r.ty, 14, 45, 30, 110, 3, 8,  0.025, 0.06);
        }
        if (r.slamT >= 1.4) { r.phase = 'fadeout'; }

      } else if (r.phase === 'fadeout') {
        r.alpha -= dt * 3;
        if (r.alpha <= 0) robots.splice(i, 1);
      }
    }
  }

  function drawRobot(ctx, r) {
    const { x, y, phase, slamT, leg, t, hit, alpha, fromSide } = r;
    ctx.save();
    ctx.globalAlpha = Math.max(0, alpha);

    const flip = fromSide === 'enemy' ? -1 : 1;
    const bob   = phase === 'walk'   ? Math.sin(t * 9) * 2.5 : 0;
    const stomp = phase === 'windup' ? -Math.min(slamT / 0.35, 1) * 12 * flip : 0;
    const slamY = phase === 'slam' && slamT < 0.15 ? (slamT / 0.15) * 16 * flip : 0;

    ctx.translate(x, y + bob * flip + stomp + slamY);
    if (fromSide === 'enemy') ctx.scale(1, -1);
    ctx.scale(0.62, 0.62);  // shrink robot to reasonable size

    // ── Ground shadow ──
    ctx.save();
    ctx.globalAlpha *= 0.22;
    ctx.fillStyle = '#000';
    ctx.beginPath(); ctx.ellipse(0, 24, 22, 5, 0, 0, Math.PI*2); ctx.fill();
    ctx.restore();

    // ── Legs ──
    const lL = leg === 0 ? 10 : 2,  lR = leg === 0 ? 2 : 10;
    const legColor  = fromSide === 'enemy' ? '#cc3030' : '#4a7ecc';
    const legColor2 = fromSide === 'enemy' ? '#991818' : '#2a5898';
    ctx.fillStyle = legColor;
    ctx.beginPath(); ctx.roundRect(-12, 8, 9, 12+lL, 3); ctx.fill();
    ctx.beginPath(); ctx.roundRect(3,   8, 9, 12+lR, 3); ctx.fill();
    ctx.fillStyle = legColor2;
    ctx.beginPath(); ctx.roundRect(-14, 18+lL, 11, 6, 2); ctx.fill();
    ctx.beginPath(); ctx.roundRect(3,   18+lR, 11, 6, 2); ctx.fill();

    // ── Torso ──
    ctx.fillStyle = fromSide === 'enemy' ? '#cc4444' : '#4488cc';
    ctx.beginPath(); ctx.roundRect(-16, -16, 32, 26, 5); ctx.fill();
    ctx.fillStyle = fromSide === 'enemy' ? '#ee6666' : '#66aaee';
    ctx.beginPath(); ctx.roundRect(-16, -16, 32, 10, [5,5,0,0]); ctx.fill();
    ctx.strokeStyle = 'rgba(255,255,255,0.12)'; ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(-16, -4); ctx.lineTo(16, -4); ctx.stroke();

    // ── Core reactor (no shadowBlur — use bright fill instead) ──
    const coreCol = hit ? '#ff7700' : (phase === 'windup' ? '#ffcc00' : '#00ddff');
    ctx.fillStyle = coreCol;
    ctx.beginPath(); ctx.arc(0, -3, 5, 0, Math.PI*2); ctx.fill();
    ctx.fillStyle = 'rgba(255,255,255,0.7)';
    ctx.beginPath(); ctx.arc(-1.5, -4.5, 1.8, 0, Math.PI*2); ctx.fill();

    // ── Arms ──
    const armAngle  = phase === 'walk' ? Math.sin(t * 9) * 0.18 : 0;
    const slamAngle = phase === 'windup' ? -(slamT/0.35)*0.7 : (phase==='slam' && slamT<0.15 ? -0.7+(slamT/0.15)*1.4 : 0);
    const armFill  = fromSide === 'enemy' ? '#cc3030' : '#4a7ecc';
    const fistFill = fromSide === 'enemy' ? '#991818' : '#2a5898';
    ctx.save(); ctx.translate(-22, -10); ctx.rotate(-armAngle + slamAngle);
    ctx.fillStyle = armFill;
    ctx.beginPath(); ctx.roundRect(-4, 0, 9, 20, 3); ctx.fill();
    ctx.fillStyle = fistFill;
    ctx.beginPath(); ctx.roundRect(-5, 17, 11, 7, 2); ctx.fill();
    ctx.restore();
    ctx.save(); ctx.translate(22, -10); ctx.rotate(armAngle - slamAngle);
    ctx.fillStyle = armFill;
    ctx.beginPath(); ctx.roundRect(-5, 0, 9, 20, 3); ctx.fill();
    ctx.fillStyle = fistFill;
    ctx.beginPath(); ctx.roundRect(-6, 17, 11, 7, 2); ctx.fill();
    ctx.restore();

    // ── Head ──
    ctx.fillStyle = fromSide === 'enemy' ? '#cc4444' : '#5590d8';
    ctx.beginPath(); ctx.roundRect(-12, -36, 24, 22, 4); ctx.fill();
    const visorCol = (phase === 'windup' || phase === 'slam') ? '#ff4400' : '#00eeff';
    ctx.fillStyle = visorCol;
    ctx.beginPath(); ctx.roundRect(-9, -30, 18, 7, 2); ctx.fill();
    ctx.fillStyle = 'rgba(255,255,255,0.35)';
    ctx.beginPath(); ctx.roundRect(-8, -29, 6, 2, 1); ctx.fill();

    // ── Antenna ──
    ctx.strokeStyle = '#88aadd'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.moveTo(0, -36); ctx.lineTo(0, -44); ctx.stroke();
    ctx.fillStyle = visorCol;
    ctx.beginPath(); ctx.arc(0, -46, 3, 0, Math.PI*2); ctx.fill();

    ctx.restore(); // end translate+scale

    // ── Slam shockwave rings ──
    if (phase === 'slam' && hit) {
      const elapsed = slamT - 0.12;
      if (elapsed > 0) {
        for (let ring = 0; ring < 3; ring++) {
          const rt = Math.max(0, elapsed - ring * 0.08);
          if (rt <= 0 || rt > 0.7) continue;
          const radius = rt * 200;
          const a = Math.max(0, (0.7 - rt) / 0.7);
          ctx.save();
          ctx.strokeStyle = `rgba(255, ${100 + ring*40}, 0, ${a})`;
          ctx.lineWidth = (4 - ring);
           
          ctx.beginPath(); ctx.arc(r.tx, r.ty, radius, 0, Math.PI*2); ctx.stroke();
          ctx.restore();
        }
        // Ground crack lines
        if (elapsed < 0.4) {
          const crackA = Math.max(0, (0.4-elapsed)/0.4);
          ctx.save(); ctx.globalAlpha = crackA * 0.7;
          ctx.strokeStyle = '#cc4400'; ctx.lineWidth = 2;
          for (let c = 0; c < 6; c++) {
            const ang = (c / 6) * Math.PI * 2;
            const len = 30 + rb(0, 40);
            ctx.beginPath();
            ctx.moveTo(r.tx, r.ty);
            ctx.lineTo(r.tx + Math.cos(ang)*len + rb(-8,8), r.ty + Math.sin(ang)*len + rb(-8,8));
            ctx.stroke();
          }
          ctx.restore();
        }
      }
    }
  }

  // ════════════════════════════════════════════════════════
  //  CANNON  –  medium damage, 2 s projectile
  // ════════════════════════════════════════════════════════
  function spawnCannon(fromSide, toSide, targetWhich, damage) {
    const sx  = CONFIG.CANVAS_W / 2;
    const sy  = fromSide === 'enemy' ? 100 : CONFIG.CANVAS_H - 100;
    const tgt = CONFIG.TOWERS[toSide][targetWhich];
    const dx = tgt.x - sx, dy = tgt.y - sy;
    const dist = Math.sqrt(dx*dx + dy*dy) || 1;
    const spd = dist / 2.0;

    cannons.push({
      tx: sx, ty: sy,
      angle: Math.atan2(dy, dx),
      bx: sx, by: sy,
      bvx: (dx/dist)*spd, bvy: (dy/dist)*spd,
      trail: [],
      toSide, targetWhich, damage,
      fromSide,
      phase: 'charge',
      chargeT: 0, turretAlpha: 1, impactT: 0,
      impactX: tgt.x, impactY: tgt.y,
      hit: false,
    });
  }

  function updateCannons(dt) {
    for (let i = cannons.length - 1; i >= 0; i--) {
      const c = cannons[i];
      if (c.phase === 'charge') {
        c.chargeT += dt;
        if (c.chargeT >= 0.55) {
          c.phase = 'fly';
          if (_shake) _shake(0.18);
        }
      } else if (c.phase === 'fly') {
        c.bx += c.bvx * dt; c.by += c.bvy * dt;
        c.trail.push({ x: c.bx, y: c.by });
        if (c.trail.length > 14) c.trail.shift();
        c.turretAlpha = Math.max(0, c.turretAlpha - dt * 1.4);

        const tgt = CONFIG.TOWERS[c.toSide][c.targetWhich];
        const dx = c.bx - tgt.x, dy = c.by - tgt.y;
        if (Math.sqrt(dx*dx+dy*dy) < 36) {
          c.phase = 'impact'; c.impactT = 0;
          if (!c.hit) {
            c.hit = true;
            if (_shake) _shake(0.35);
            if (_damage) _damage(c.toSide, c.targetWhich, c.damage);
            burst(tgt.x, tgt.y, 20, 28, 50, 180, 3, 10, 0.025, 0.055);
            burst(tgt.x, tgt.y, 10, 50, 20, 80,  2, 6,  0.04,  0.07);
          }
        }
      } else if (c.phase === 'impact') {
        c.impactT += dt;
        if (c.impactT >= 0.8) cannons.splice(i, 1);
      }
    }
  }

  function drawCannon(ctx, c) {
    const { tx, ty, angle, chargeT, phase, bx, by, trail, turretAlpha, impactT, impactX, impactY, fromSide } = c;

    // ── Cannon turret ──
    if (turretAlpha > 0.01) {
      ctx.save();
      ctx.globalAlpha = Math.min(turretAlpha * 3, 1);
      ctx.translate(tx, ty);
      if (fromSide === 'enemy') ctx.scale(1, -1); // flip turret for enemy

      // Wheels
      [[-16, 14],[16, 14]].forEach(([wx, wy]) => {
        ctx.fillStyle = '#5a4030';
        ctx.beginPath(); ctx.arc(wx, wy, 9, 0, Math.PI*2); ctx.fill();
        ctx.strokeStyle = '#3a2010'; ctx.lineWidth = 2;
        ctx.beginPath(); ctx.arc(wx, wy, 9, 0, Math.PI*2); ctx.stroke();
        // Spokes
        ctx.strokeStyle = '#3a2010'; ctx.lineWidth = 1.5;
        for (let s = 0; s < 4; s++) {
          const a = (s/4)*Math.PI*2;
          ctx.beginPath(); ctx.moveTo(wx, wy); ctx.lineTo(wx+Math.cos(a)*8, wy+Math.sin(a)*8); ctx.stroke();
        }
      });
      // Axle
      ctx.strokeStyle = '#3a2010'; ctx.lineWidth = 3.5;
      ctx.beginPath(); ctx.moveTo(-16, 14); ctx.lineTo(16, 14); ctx.stroke();
      // Carriage body
      ctx.fillStyle = '#7a4e28';
      ctx.beginPath(); ctx.roundRect(-18, -4, 36, 18, 4); ctx.fill();
      ctx.fillStyle = '#5a3018';
      ctx.fillRect(-16, -2, 32, 4);
      // Metal bands
      ctx.strokeStyle = '#3a2010'; ctx.lineWidth = 2;
      [-8, 0, 8].forEach(bx2 => { ctx.beginPath(); ctx.moveTo(bx2,-4); ctx.lineTo(bx2,14); ctx.stroke(); });

      // Barrel (rotated)
      ctx.rotate(angle);

      // Charge glow at barrel mouth
      if (phase === 'charge' && chargeT > 0.05) {
        const glowPct = chargeT / 0.55;
        ctx.save();
        ctx.translate(44, 0);
        for (let g = 0; g < 3; g++) {
          ctx.globalAlpha = glowPct * (0.5 - g*0.15);
          ctx.fillStyle = `hsl(${50-g*10}, 100%, ${70-g*10}%)`;
           
          ctx.beginPath(); ctx.arc(0, 0, (8 + g*6) * glowPct, 0, Math.PI*2); ctx.fill();
        }
        ctx.restore();
      }

      // Barrel body
      const bGrad = ctx.createLinearGradient(0, -8, 0, 8);
      bGrad.addColorStop(0, '#999'); bGrad.addColorStop(0.4, '#ddd'); bGrad.addColorStop(1, '#555');
      ctx.fillStyle = bGrad; ctx.globalAlpha = 1;
      ctx.beginPath(); ctx.roundRect(0, -8, 44, 16, 5); ctx.fill();
      // Reinforcement bands
      ctx.fillStyle = '#555';
      [10, 22, 34].forEach(bpos => { ctx.fillRect(bpos, -8, 5, 16); });
      // Muzzle
      ctx.fillStyle = '#333';
      ctx.beginPath(); ctx.roundRect(40, -6, 6, 12, 2); ctx.fill();

      ctx.restore();
    }

    // ── Cannonball in flight ──
    if (phase === 'fly') {
      trail.forEach((pt, ti) => {
        const frac = ti / trail.length;
        ctx.save();
        ctx.globalAlpha = frac * 0.55;
        ctx.fillStyle = '#ff8800';
         
        ctx.beginPath(); ctx.arc(pt.x, pt.y, 8 * frac, 0, Math.PI*2); ctx.fill();
        ctx.restore();
      });
      // Ball
      const bGrad2 = ctx.createRadialGradient(bx-3, by-3, 0, bx, by, 13);
      bGrad2.addColorStop(0, '#ffdd66'); bGrad2.addColorStop(0.4, '#cc4400'); bGrad2.addColorStop(1, '#220000');
      ctx.save();
      ctx.fillStyle = bGrad2;
       
      ctx.beginPath(); ctx.arc(bx, by, 13, 0, Math.PI*2); ctx.fill();
      // Highlight
      ctx.fillStyle = 'rgba(255,200,100,0.5)';
      ctx.beginPath(); ctx.arc(bx-4, by-4, 4, 0, Math.PI*2); ctx.fill();
      ctx.restore();
    }

    // ── Impact explosion ──
    if (phase === 'impact') {
      // Draw expanding explosion rings (no external IMG needed)
      const progress = Math.min(impactT / 0.8, 1);
      // Main fireball
      const fbR = 8 + progress * 55;
      const fbA = Math.max(0, 1 - progress * 1.2);
      const fbGrad = ctx.createRadialGradient(impactX, impactY, 0, impactX, impactY, fbR);
      fbGrad.addColorStop(0,   `rgba(255,240,180,${fbA})`);
      fbGrad.addColorStop(0.3, `rgba(255,140,0,${fbA * 0.9})`);
      fbGrad.addColorStop(0.7, `rgba(220,60,0,${fbA * 0.6})`);
      fbGrad.addColorStop(1,   `rgba(80,20,0,0)`);
      ctx.save();
      ctx.fillStyle = fbGrad;
      ctx.beginPath(); ctx.arc(impactX, impactY, fbR, 0, Math.PI*2); ctx.fill();
      ctx.restore();
      // Expanding shockwave rings
      for (let ring = 0; ring < 3; ring++) {
        const rt = impactT - ring * 0.08;
        if (rt <= 0 || rt > 0.72) continue;
        const radius = rt * 170;
        const alpha  = Math.max(0, (0.72 - rt) / 0.72);
        ctx.save();
        ctx.globalAlpha = alpha;
        ctx.strokeStyle = ring === 0 ? '#ffaa00' : `rgba(255,${100+ring*30},0,1)`;
        ctx.lineWidth = 4 - ring * 0.8;
         
        ctx.beginPath(); ctx.arc(impactX, impactY, radius, 0, Math.PI*2); ctx.stroke();
        ctx.restore();
      }
    }
  }

  // ════════════════════════════════════════════════════════
  //  WIZARD  –  low damage, near-instant lightning
  // ════════════════════════════════════════════════════════
  function genBolt(x1, y1, x2, y2, segs = 9) {
    const pts = [{ x: x1, y: y1 }];
    const len = Math.sqrt((x2-x1)**2 + (y2-y1)**2);
    const nx = -(y2-y1)/len, ny = (x2-x1)/len; // perpendicular unit
    for (let s = 1; s < segs; s++) {
      const t = s / segs;
      pts.push({
        x: x1 + (x2-x1)*t + nx * rb(-26, 26),
        y: y1 + (y2-y1)*t + ny * rb(-26, 26),
      });
    }
    pts.push({ x: x2, y: y2 });
    return pts;
  }

  function spawnWizard(fromSide, toSide, targetWhich, damage) {
    const sx  = CONFIG.CANVAS_W / 2;
    const sy  = fromSide === 'enemy' ? 80 : CONFIG.CANVAS_H - 80;
    const tgt = CONFIG.TOWERS[toSide][targetWhich];
    const boltStartY = fromSide === 'enemy' ? sy + 20 : sy - 20;
    wizards.push({
      x: sx, y: sy,
      targetX: tgt.x, targetY: tgt.y,
      toSide, targetWhich, damage,
      fromSide,
      phase: 'cast',
      castT: 0, boltT: 0, flashT: 0,
      bolt1: genBolt(sx, boltStartY, tgt.x, tgt.y),
      bolt2: genBolt(sx, boltStartY, tgt.x, tgt.y),
      hit: false, wizAlpha: 1,
    });
  }

  function updateWizards(dt) {
    for (let i = wizards.length - 1; i >= 0; i--) {
      const w = wizards[i];
      if (w.phase === 'cast') {
        w.castT += dt;
        if (w.castT >= 0.32) { w.phase = 'bolt'; w.boltT = 0; }

      } else if (w.phase === 'bolt') {
        w.boltT += dt;
        if (w.boltT >= 0.28) {
          w.phase = 'flash'; w.flashT = 0;
          if (!w.hit) {
            w.hit = true;
            if (_shake) _shake(0.28);
            if (_damage) _damage(w.toSide, w.targetWhich, w.damage);
            burst(w.targetX, w.targetY, 24, 210, 35, 130, 2, 8,  0.04,  0.09);
            burst(w.targetX, w.targetY, 12, 190, 15, 60,  2, 5,  0.05,  0.1);
          }
        }
        w.wizAlpha = Math.max(0, w.wizAlpha - dt * 1.2);

      } else if (w.phase === 'flash') {
        w.flashT += dt;
        w.wizAlpha = 0;
        if (w.flashT >= 0.6) wizards.splice(i, 1);
      }
    }
  }

  function drawWizard(ctx, w) {
    const { x, y, phase, castT, boltT, flashT, bolt1, bolt2, targetX, targetY, wizAlpha, fromSide } = w;

    // ── Wizard sprite ──
    if (wizAlpha > 0.01) {
      ctx.save();
      ctx.globalAlpha = wizAlpha;
      ctx.translate(x, y);
      if (fromSide === 'enemy') ctx.scale(1, -1);  // flip for enemy wizard

      const castPct = Math.min(castT / 0.32, 1);

      // Shadow
      ctx.save(); ctx.globalAlpha *= 0.2;
      ctx.fillStyle = '#000';
      ctx.beginPath(); ctx.ellipse(0, 28, 16, 4, 0, 0, Math.PI*2); ctx.fill();
      ctx.restore();

      // Robe
      const robeGrad = ctx.createLinearGradient(-14, -10, 14, 30);
      robeGrad.addColorStop(0, '#7722bb'); robeGrad.addColorStop(1, '#3311aa');
      ctx.fillStyle = robeGrad;
      ctx.beginPath();
      ctx.moveTo(-12, 30); ctx.quadraticCurveTo(-16, 10, -12, -10);
      ctx.lineTo(0, -12);
      ctx.lineTo(12, -10); ctx.quadraticCurveTo(16, 10, 12, 30);
      ctx.closePath(); ctx.fill();
      // Robe sheen
      ctx.fillStyle = 'rgba(200,130,255,0.2)';
      ctx.beginPath();
      ctx.moveTo(-4, 28); ctx.quadraticCurveTo(-6, 10, -4, -10);
      ctx.lineTo(0, -12); ctx.lineTo(2, -10); ctx.quadraticCurveTo(4, 10, 2, 28);
      ctx.closePath(); ctx.fill();
      // Star decorations on robe
      ctx.fillStyle = 'rgba(255,220,100,0.6)';
      ctx.font = '7px sans-serif'; ctx.textAlign = 'center';
      ctx.fillText('✦', -5, 5); ctx.fillText('✦', 5, 18);

      // Head
      ctx.fillStyle = '#e8c8a0';
      ctx.beginPath(); ctx.ellipse(0, -18, 8, 10, 0, 0, Math.PI*2); ctx.fill();

      // Beard
      ctx.fillStyle = '#ddddff';
      ctx.beginPath(); ctx.ellipse(0, -10, 6, 5, 0, 0, Math.PI); ctx.fill();

      // Hat brim
      ctx.fillStyle = '#2211aa';
      ctx.beginPath(); ctx.ellipse(0, -25, 13, 4, 0, 0, Math.PI*2); ctx.fill();
      // Hat cone
      ctx.fillStyle = '#3322cc';
      ctx.beginPath();
      ctx.moveTo(-10, -25); ctx.lineTo(10, -25); ctx.lineTo(3, -50); ctx.closePath(); ctx.fill();
      // Hat shine
      ctx.fillStyle = 'rgba(150,120,255,0.3)';
      ctx.beginPath();
      ctx.moveTo(-2, -25); ctx.lineTo(1, -25); ctx.lineTo(3, -50); ctx.closePath(); ctx.fill();
      // Hat star
      ctx.fillStyle = '#ffee44';
      ctx.font = '9px sans-serif'; ctx.textAlign = 'center';
       
      ctx.fillText('★', 1, -36);
      

      // Eyes
      ctx.fillStyle = '#fff';
      ctx.beginPath(); ctx.ellipse(-3, -20, 2.8, 2.2, 0, 0, Math.PI*2); ctx.fill();
      ctx.beginPath(); ctx.ellipse(3,  -20, 2.8, 2.2, 0, 0, Math.PI*2); ctx.fill();
      const eyeCol = castPct > 0.5 ? `rgba(${Math.round(castPct*255)},50,255,1)` : '#8800ee';
      ctx.fillStyle = eyeCol;
       
      ctx.beginPath(); ctx.arc(-3, -20, 1.3, 0, Math.PI*2); ctx.fill();
      ctx.beginPath(); ctx.arc(3,  -20, 1.3, 0, Math.PI*2); ctx.fill();
      

      // Staff
      ctx.strokeStyle = '#9B7320'; ctx.lineWidth = 3;
      ctx.beginPath(); ctx.moveTo(14, 28); ctx.lineTo(14, -14); ctx.stroke();
      ctx.strokeStyle = '#7B5300'; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(14, 28); ctx.lineTo(14, -14); ctx.stroke();

      // Staff orb
      const orbR = 5 + castPct * 6;
      const orbCol = castPct > 0.7 ? '#aaeeff' : '#8844cc';
      ctx.save();
       
      ctx.fillStyle = orbCol;
      ctx.beginPath(); ctx.arc(14, -17, orbR, 0, Math.PI*2); ctx.fill();
      ctx.fillStyle = 'rgba(255,255,255,0.5)';
      ctx.beginPath(); ctx.arc(11.5, -19.5, orbR * 0.4, 0, Math.PI*2); ctx.fill();
      ctx.restore();

      // Cast circle
      if (castT > 0.05) {
        ctx.strokeStyle = `rgba(160, 80, 255, ${castPct * 0.7})`;
        ctx.lineWidth = 2;
         
        ctx.beginPath(); ctx.arc(0, 28, 22 * castPct, 0, Math.PI*2); ctx.stroke();
        
        // Rune marks
        for (let rn = 0; rn < 4; rn++) {
          const ra = (rn / 4) * Math.PI * 2 + castT * 3;
          const rx = Math.cos(ra) * 22 * castPct;
          const ry = 28 + Math.sin(ra) * 22 * castPct;
          ctx.fillStyle = `rgba(200,120,255,${castPct * 0.8})`;
          ctx.font = '8px sans-serif'; ctx.textAlign = 'center';
          ctx.fillText(['◇','△','○','□'][rn], rx, ry);
        }
      }

      ctx.restore();
    }

    // ── Lightning bolt ──
    if (phase === 'bolt' || phase === 'flash') {
      const progress = phase === 'bolt' ? Math.min(boltT / 0.28, 1) : 1;
      const flashFade = phase === 'flash' ? Math.max(0, 1 - flashT / 0.5) : 1;
      const segs = Math.max(2, Math.round(bolt1.length * progress));

      const drawBolt = (bolt, width, color, glow, alpha) => {
        if (segs < 2) return;
        ctx.save();
        ctx.globalAlpha = alpha * flashFade;
        ctx.strokeStyle = color;
        ctx.lineWidth = width;
         
        ctx.lineJoin = 'round';
        ctx.beginPath();
        ctx.moveTo(bolt[0].x, bolt[0].y);
        for (let s = 1; s < segs; s++) ctx.lineTo(bolt[s].x, bolt[s].y);
        ctx.stroke();
        ctx.restore();
      };

      // Outer glow
      drawBolt(bolt1, 10, 'rgba(100,180,255,0.3)', '#0044ff', 1);
      // Second branch (slightly offset)
      drawBolt(bolt2,  6, 'rgba(180,220,255,0.25)', '#0066ff', 0.7);
      // Main bolt
      drawBolt(bolt1,  3, '#aaeeff', '#0088ff', 1);
      // Inner white core
      drawBolt(bolt1, 1.5, '#ffffff', '#ffffff', 0.9);

      // Sparks along bolt
      if (progress > 0.5) {
        const sparkPts = bolt1.slice(0, segs);
        sparkPts.forEach((pt, si) => {
          if (si % 2 !== 0) return;
          const sa = flashFade * 0.5;
          ctx.save();
          ctx.globalAlpha = sa;
          ctx.fillStyle = '#aaeeff';
           
          ctx.beginPath(); ctx.arc(pt.x + rb(-3,3), pt.y + rb(-3,3), rb(1, 3), 0, Math.PI*2); ctx.fill();
          ctx.restore();
        });
      }
    }

    // ── Impact flash at target ──
    if (phase === 'flash') {
      const fa = Math.max(0, 1 - flashT / 0.6);
      // Bright flash circle expanding
      ctx.save();
      ctx.globalAlpha = fa * 0.7;
      const fGrad = ctx.createRadialGradient(targetX, targetY, 0, targetX, targetY, 40 + flashT * 90);
      fGrad.addColorStop(0, 'rgba(200,240,255,1)');
      fGrad.addColorStop(0.4, 'rgba(100,180,255,0.6)');
      fGrad.addColorStop(1, 'rgba(0,80,200,0)');
      ctx.fillStyle = fGrad;
      ctx.beginPath(); ctx.arc(targetX, targetY, 40 + flashT * 90, 0, Math.PI*2); ctx.fill();
      ctx.restore();

      // Electric rings
      for (let ring = 0; ring < 3; ring++) {
        const rt = flashT - ring * 0.07;
        if (rt <= 0 || rt > 0.55) continue;
        const radius = rt * 130;
        const ra = Math.max(0, (0.55 - rt) / 0.55) * fa;
        ctx.save();
        ctx.globalAlpha = ra;
        ctx.strokeStyle = ring === 0 ? '#ffffff' : '#00ccff';
        ctx.lineWidth = 3 - ring * 0.8;
         
        ctx.beginPath(); ctx.arc(targetX, targetY, radius, 0, Math.PI*2); ctx.stroke();
        ctx.restore();
      }

      // Zigzag tendrils
      if (flashT < 0.3) {
        for (let t2 = 0; t2 < 4; t2++) {
          const ta = (t2 / 4) * Math.PI * 2 + flashT * 8;
          const tlen = (0.3 - flashT) / 0.3 * 35;
          ctx.save();
          ctx.globalAlpha = fa * 0.6;
          ctx.strokeStyle = '#88ccff'; ctx.lineWidth = 1.5;
          ctx.beginPath();
          ctx.moveTo(targetX, targetY);
          for (let ts = 0; ts < 4; ts++) {
            const tp = ts / 4;
            ctx.lineTo(
              targetX + Math.cos(ta + tp * 0.8) * tlen * tp + rb(-5,5),
              targetY + Math.sin(ta + tp * 0.8) * tlen * tp + rb(-5,5)
            );
          }
          ctx.stroke();
          ctx.restore();
        }
      }
    }
  }

  // ════════════════════════════════════════════════════════
  //  Decorative trees for arena sides
  // ════════════════════════════════════════════════════════
  function drawSideTrees(ctx, t) {
    const W = CONFIG.CANVAS_W, H = CONFIG.CANVAS_H;
    const treePositions = [
      { x: 6,   y: 80,  s: 0.85, hue: 120 },
      { x: 8,   y: 190, s: 0.75, hue: 130 },
      { x: 5,   y: 320, s: 0.9,  hue: 115 },
      { x: 9,   y: 450, s: 0.8,  hue: 125 },
      { x: W-6, y: 80,  s: 0.8,  hue: 125 },
      { x: W-8, y: 200, s: 0.9,  hue: 118 },
      { x: W-5, y: 340, s: 0.75, hue: 130 },
      { x: W-9, y: 460, s: 0.85, hue: 122 },
    ];

    treePositions.forEach((tr, idx) => {
      const sway = Math.sin(t * 0.8 + idx * 1.4) * 1.5;
      ctx.save();
      ctx.translate(tr.x, tr.y);
      ctx.scale(tr.s, tr.s);

      // Trunk
      ctx.fillStyle = '#5a3a1a';
      ctx.beginPath(); ctx.roundRect(-3, 0, 6, 18, 2); ctx.fill();

      // Canopy layers (drawn back to front)
      const shades = [
        `hsl(${tr.hue}, 55%, 22%)`,
        `hsl(${tr.hue}, 60%, 28%)`,
        `hsl(${tr.hue}, 65%, 34%)`,
      ];
      [
        { y: 6,  r: 13, shade: 0 },
        { y: -2, r: 11, shade: 1 },
        { y:-10, r:  9, shade: 2 },
      ].forEach(layer => {
        ctx.save();
        ctx.translate(sway * (layer.y * -0.04), 0);
        ctx.fillStyle = shades[layer.shade];
         
        ctx.beginPath(); ctx.arc(0, layer.y, layer.r, 0, Math.PI*2); ctx.fill();
        
        ctx.restore();
      });

      ctx.restore();
    });
  }

  // ════════════════════════════════════════════════════════
  //  Public API
  // ════════════════════════════════════════════════════════
  // fromSide: 'player' = bottom→up, 'enemy' = top→down
  function spawnAttack(type, fromSide, toSide, targetWhich, damage) {
    if (type === 'robot')  spawnRobot(fromSide, toSide, targetWhich, damage);
    if (type === 'cannon') spawnCannon(fromSide, toSide, targetWhich, damage);
    if (type === 'wizard') spawnWizard(fromSide, toSide, targetWhich, damage);
  }

  function update(dt) {
    updateRobots(dt);
    updateCannons(dt);
    updateWizards(dt);
  }

  function draw(ctx, t) {
    drawSideTrees(ctx, t);
    robots.forEach(r  => drawRobot(ctx, r));
    cannons.forEach(c => drawCannon(ctx, c));
    wizards.forEach(w => drawWizard(ctx, w));
  }

  return { init, reset, spawnAttack, update, draw };

})();
