// ============================================================
//  ui.js  –  DOM rendering, notifications, menus
// ============================================================

const UI = (() => {

  // ── Element refs ──────────────────────────────────────────
  const deckEl      = document.getElementById('deck');
  const enemyDeckEl = document.getElementById('enemy-deck');
  const modal       = document.getElementById('question-modal');
  const modalQ      = document.getElementById('modal-question');
  const modalOpts   = document.getElementById('modal-options');
  const modalCancel = document.getElementById('modal-cancel');
  const feedbackEl  = document.getElementById('answer-feedback');
  const timerRing   = document.getElementById('timer-ring');
  const timerText   = document.getElementById('timer-text');
  const overlay     = document.getElementById('gameover-overlay');
  const modalCat    = document.getElementById('modal-cat-badge');
  const powerHint   = document.getElementById('power-hint');
  const toastCont   = document.getElementById('toast-container');
  const streakWrap  = document.getElementById('streak-wrap');
  const streakNum   = document.getElementById('streak-num');
  const comboBadge  = document.getElementById('combo-badge');
  const comboVal    = document.getElementById('combo-val');
  const powerBadge  = document.getElementById('power-badge');

  // HP bar refs
  const hpBars = {};
  ['player','enemy'].forEach(s => ['main','miniLeft','miniRight'].forEach(w => {
    hpBars[`${s}-${w}`] = {
      fill: document.getElementById(`hp-${s}-${w}`),
      text: document.getElementById(`hp-${s}-${w}-text`),
    };
  }));
  const hudBars = {
    'enemy-main':  document.getElementById('hud-hp-enemy-main'),
    'player-main': document.getElementById('hud-hp-player-main'),
  };

  // ── Screens ───────────────────────────────────────────────
  function showScreen(name) {
    ['menu-screen', 'mp-screen', 'game-wrapper'].forEach(id => {
      const el = document.getElementById(id);
      if (!el) return;
      el.classList.remove('active');
    });
    const targets = { menu: 'menu-screen', mp: 'mp-screen', game: 'game-wrapper' };
    const el = document.getElementById(targets[name]);
    if (el) el.classList.add('active');
  }

  // ── Menu particles ────────────────────────────────────────
  function initMenuParticles() {
    const container = document.getElementById('menu-particles');
    if (!container) return;
    const colors = ['#3eaaff','#c044ff','#ffd23f','#22c55e','#ff6060'];
    for (let i = 0; i < 25; i++) {
      const p = document.createElement('div');
      p.className = 'mparticle';
      const size = 3 + Math.random() * 6;
      p.style.cssText = `
        width:${size}px; height:${size}px;
        left:${Math.random()*100}%;
        background:${colors[Math.floor(Math.random()*colors.length)]};
        animation-duration:${6+Math.random()*10}s;
        animation-delay:${-Math.random()*15}s;
        box-shadow:0 0 ${size*2}px currentColor;
        color:${colors[Math.floor(Math.random()*colors.length)]};
      `;
      container.appendChild(p);
    }
  }

  // ── Enemy deck (mystery cards) ────────────────────────────
  function buildEnemyDeck() {
    enemyDeckEl.innerHTML = '';
    for (let i = 0; i < 4; i++) {
      const el = document.createElement('div');
      el.className = 'enemy-card';
      el.id = `ecard-${i}`;
      el.innerHTML = `<img src="assets/enemy_card.png" alt="?" loading="eager"/>`;
      enemyDeckEl.appendChild(el);
    }
  }

  // Flash enemy card when they attack
  function flashEnemyCard(index) {
    const card = document.getElementById(`ecard-${index}`);
    if (!card) return;
    card.classList.remove('flash');
    void card.offsetWidth; // reflow
    card.classList.add('flash');
    setTimeout(() => card.classList.remove('flash'), 600);
  }

  // ── Player deck ───────────────────────────────────────────
  function buildDeck(cards, onCardClick) {
    deckEl.innerHTML = '';
    buildEnemyDeck();

    cards.forEach(card => {
      const el = document.createElement('div');
      el.className = 'card ' + (card.type === 'heal' ? 'card-heal' : 'card-attack');
      el.id = `card-${card.id}`;
      el.style.setProperty('--card-glow', card.glowColor);
      el.innerHTML = `
        <img class="card-img-full" src="assets/${card.asset}" alt="${card.name}" loading="eager"/>
        <div class="card-badge">${card.label}</div>
        ${card.type === 'heal' ? '<div class="card-heal-icon">💚</div>' : ''}
      `;
      el.addEventListener('click', () => onCardClick(card));
      deckEl.appendChild(el);
    });
  }

  // Show/hide combo boost badge on a card
  function showCardBoost(cardId, multiplier) {
    const el = document.getElementById(`card-${cardId}`);
    if (!el) return;
    let badge = el.querySelector('.card-boost-badge');
    if (!badge) {
      badge = document.createElement('div');
      badge.className = 'card-boost-badge';
      el.appendChild(badge);
    }
    badge.textContent = `×${multiplier.toFixed(1)}`;
  }
  function hideCardBoosts() {
    document.querySelectorAll('.card-boost-badge').forEach(b => b.remove());
  }

  // ── Tower HP ──────────────────────────────────────────────
  function updateTowerHp(side, which, hp, maxHp) {
    const bar = hpBars[`${side}-${which}`];
    if (!bar) return;
    const pct = Math.max(0, (hp / maxHp) * 100);
    bar.fill.style.width  = pct + '%';
    bar.fill.style.background = pct > 55 ? '#22c55e' : pct > 28 ? '#f59e0b' : '#ef4444';
    bar.text.textContent  = Math.max(0, Math.floor(hp));

    if (which === 'main') {
      const hud = hudBars[`${side}-main`];
      if (hud) hud.style.width = pct + '%';
    }

    // Flash tower image on hit
    if (hp < maxHp) {
      const img = document.getElementById(`tower-img-${side}-${which}`);
      if (img && !img.classList.contains('destroyed')) {
        img.classList.remove('hit-flash');
        void img.offsetWidth;
        img.classList.add('hit-flash');
        setTimeout(() => img.classList.remove('hit-flash'), 350);
      }
    }
  }

  const _cm = { player: 'blue', enemy: 'red' };
  function setTowerDestroyed(side, which) {
    const img = document.getElementById(`tower-img-${side}-${which}`);
    if (!img) return;
    const isMain = which === 'main';
    img.src = `assets/${_cm[side]}_${isMain ? 'maintower' : 'minitower'}_destroyed.png`;
    img.classList.add('destroyed');
  }

  // ── Question modal ────────────────────────────────────────
  let _timer = null, _timeLeft = 0;

  function showQuestion(question, card, onAnswer, onTimeout, isPowerRound = false) {
    modal.classList.add('active');
    modalQ.textContent = question.q;

    // Category badge + accent
    const catColors = { math:'#3b82f6', science:'#10b981', logic:'#a855f7', general:'#f59e0b' };
    const accent = card.type === 'heal' ? '#22c55e' : (catColors[card.category] || card.color);
    modal.querySelector('.modal-box').style.setProperty('--modal-accent', accent);
    modalCat.textContent = card.label;
    modalCat.style.setProperty('--modal-accent', accent);

    // Power round hint
    if (isPowerRound) {
      powerHint.classList.remove('hidden');
    } else {
      powerHint.classList.add('hidden');
    }

    modalOpts.innerHTML = '';
    feedbackEl.textContent = '';
    feedbackEl.className = 'answer-feedback';

    question.options.forEach((opt, i) => {
      const btn = document.createElement('button');
      btn.className = 'opt-btn';
      btn.textContent = opt;
      btn.addEventListener('click', () => {
        clearInterval(_timer);
        const ok = i === question.answer;
        btn.classList.add(ok ? 'correct' : 'wrong');
        modalOpts.querySelectorAll('.opt-btn').forEach(b => b.disabled = true);
        feedbackEl.textContent = ok
          ? (card.type === 'heal' ? '💚 Correct! Healing launched!' : '✓ Correct! Attack launched!')
          : '✗ Wrong! Nothing happened.';
        feedbackEl.className = 'answer-feedback ' + (ok ? 'correct' : 'wrong');
        setTimeout(() => { hideQuestion(); onAnswer(ok, _timeLeft); }, 820);
      });
      modalOpts.appendChild(btn);
    });

    const duration = isPowerRound ? 10 : 10;
    _timeLeft = duration;
    updateTimerRing(duration, duration);
    clearInterval(_timer);
    _timer = setInterval(() => {
      _timeLeft -= 0.05;
      updateTimerRing(_timeLeft, duration);
      if (_timeLeft <= 0) {
        clearInterval(_timer);
        feedbackEl.textContent = '⏰ Time\'s up!';
        feedbackEl.className = 'answer-feedback wrong';
        modalOpts.querySelectorAll('.opt-btn').forEach(b => b.disabled = true);
        setTimeout(() => { hideQuestion(); onTimeout(); }, 820);
      }
    }, 50);
  }

  function hideQuestion() {
    modal.classList.remove('active');
    powerHint.classList.add('hidden');
    clearInterval(_timer);
  }

  function updateTimerRing(tl, total) {
    const pct = tl / total;
    timerRing.style.strokeDashoffset = (2 * Math.PI * 20) * (1 - pct);
    timerRing.style.stroke = pct > 0.5 ? '#22c55e' : pct > 0.25 ? '#f59e0b' : '#ef4444';
    timerText.textContent = Math.ceil(Math.max(0, tl));
  }

  modalCancel.addEventListener('click', () => {
    clearInterval(_timer);
    hideQuestion();
    if (UI._onCancel) UI._onCancel();
  });

  // ── Game Over ─────────────────────────────────────────────
  function showGameOver(won, stats, onRestart, onMenu) {
    overlay.classList.add('active');

    const emojiEl = document.getElementById('go-emoji');
    const titleEl = document.getElementById('gameover-title');
    const msgEl   = document.getElementById('gameover-msg');
    const statsEl = document.getElementById('gameover-stats');

    titleEl.textContent = won ? '🏆 VICTORY!' : '💀 DEFEAT!';
    titleEl.style.color = won ? '#22c55e' : '#ef4444';
    emojiEl.textContent = won ? '🏆' : '💀';
    msgEl.textContent   = won ? 'You destroyed the enemy base!' : 'Your base has fallen…';

    // Stats chips
    if (stats) {
      statsEl.innerHTML = '';
      const items = [
        { val: stats.correct,  lbl: 'Correct' },
        { val: stats.total,    lbl: 'Questions' },
        { val: stats.maxStreak,lbl: 'Best Streak' },
        { val: Math.round(stats.accuracy) + '%', lbl: 'Accuracy' },
      ];
      items.forEach(item => {
        const chip = document.createElement('div');
        chip.className = 'stat-chip';
        chip.innerHTML = `<div class="stat-chip-val">${item.val}</div><div class="stat-chip-lbl">${item.lbl}</div>`;
        statsEl.appendChild(chip);
      });
    }

    document.getElementById('restart-btn').onclick = () => {
      overlay.classList.remove('active');
      if (onRestart) onRestart();
    };
    document.getElementById('menu-btn-go').onclick = () => {
      overlay.classList.remove('active');
      if (onMenu) onMenu();
    };
  }

  // ── Toast notifications ───────────────────────────────────
  function toast(icon, message, type = 'info', duration = 2600) {
    const el = document.createElement('div');
    el.className = `toast toast-${type}`;
    el.innerHTML = `<span>${icon}</span><span>${message}</span>`;
    toastCont.appendChild(el);
    setTimeout(() => el.remove(), duration + 100);
  }

  function toastEnemyAttack(cardLabel) {
    toast('⚔', `Enemy attacks with ${cardLabel}!`, 'enemy');
  }
  function toastPlayerCorrect() {
    toast('✓', 'Correct! Attack launched!', 'correct');
  }
  function toastPlayerWrong() {
    toast('✗', 'Wrong answer!', 'wrong');
  }
  function toastHeal() {
    toast('💚', 'Healing launched!', 'correct');
  }
  function toastPowerRound() {
    toast('⚡', 'POWER ROUND — Double damage available!', 'power', 3000);
  }
  function toastOpponentConnected(name = 'Opponent') {
    toast('🌐', `${name} connected! Get ready!`, 'info', 3000);
  }
  function toastOpponentDisconnected() {
    toast('🔌', 'Opponent disconnected!', 'wrong', 3000);
  }

  // ── Streak display ────────────────────────────────────────
  function updateStreak(n) {
    if (n >= 2) {
      streakWrap.style.display = 'flex';
      streakNum.textContent = n;
    } else {
      streakWrap.style.display = 'none';
    }
  }

  // ── Combo display ─────────────────────────────────────────
  function showCombo(streak) {
    if (streak < 2) return;
    comboVal.textContent = `${streak}×`;
    comboBadge.classList.remove('hidden', 'show');
    void comboBadge.offsetWidth;
    comboBadge.classList.add('show');
    setTimeout(() => comboBadge.classList.remove('show'), 2100);
  }

  // ── Power round flash ─────────────────────────────────────
  function showPowerRound() {
    powerBadge.classList.remove('hidden', 'show');
    void powerBadge.offsetWidth;
    powerBadge.classList.add('show');
    setTimeout(() => { powerBadge.classList.remove('show'); powerBadge.classList.add('hidden'); }, 3000);
    toastPowerRound();
  }

  // ── Floating text ─────────────────────────────────────────
  function floatDamage(x, y, text, cls) {
    const el = document.createElement('div');
    el.className = 'float-dmg ' + cls;
    el.textContent = text;
    el.style.left = x + 'px';
    el.style.top  = y + 'px';
    document.getElementById('arena-container').appendChild(el);
    setTimeout(() => el.remove(), 1050);
  }

  return {
    showScreen, initMenuParticles,
    buildDeck, buildEnemyDeck,
    flashEnemyCard,
    updateTowerHp, setTowerDestroyed,
    showQuestion, hideQuestion,
    showGameOver, floatDamage,
    showCardBoost, hideCardBoosts,
    updateStreak, showCombo, showPowerRound,
    toast,
    toastEnemyAttack, toastPlayerCorrect, toastPlayerWrong, toastHeal, toastPowerRound,
    toastOpponentConnected, toastOpponentDisconnected,
    _onCancel: null,
  };
})();
