import { spawn } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { createConnection } from 'node:net';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createClient } from '@supabase/supabase-js';
import { io } from 'socket.io-client';

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const projectDirectory = resolve(scriptDirectory, '..');
const envFile = resolve(
  projectDirectory,
  process.env.GAME_SMOKE_ENV_FILE ?? '../backend-api/.env',
);
if (existsSync(envFile)) {
  for (const line of readFileSync(envFile, 'utf8').split(/\r?\n/)) {
    const match = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$/);
    if (!match || process.env[match[1]]) continue;
    const value = match[2].replace(/^(['"])(.*)\1$/, '$2');
    process.env[match[1]] = value;
  }
}

const supabaseUrl = process.env.SUPABASE_URL;
const publicKey = process.env.SUPABASE_KEY;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const gameUrl = process.env.GAME_SMOKE_URL ?? 'http://127.0.0.1:3101';

if (!supabaseUrl || !publicKey || !serviceRoleKey) {
  throw new Error(
    'SUPABASE_URL, SUPABASE_KEY, and SUPABASE_SERVICE_ROLE_KEY are required.',
  );
}

const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});
const suffix = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
const password = `Smoke-${suffix}-Aa1!`;
const users = [];
const sockets = [];
let roomId;
let gameServer;
let serverOutput = '';

function event(socket, name, timeoutMs = 12_000) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      socket.off(name, onEvent);
      reject(new Error(`Timed out waiting for ${name}.`));
    }, timeoutMs);
    const onEvent = (payload) => {
      clearTimeout(timer);
      resolve(payload);
    };
    socket.once(name, onEvent);
  });
}

async function createSmokeUser(label) {
  const email = `match-smoke-${label}-${suffix}@example.com`;
  const username = `smoke_${label}_${suffix.replace(/\W/g, '').slice(-12)}`;
  const { data, error } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: {
      full_name: `Smoke ${label.toUpperCase()}`,
      username,
      target: 'cpns',
    },
  });
  if (error || !data.user) {
    throw new Error(`Unable to create smoke user ${label}: ${error?.message}`);
  }
  users.push(data.user.id);

  const { error: profileError } = await admin
    .from('profiles')
    .update({
      full_name: `Smoke ${label.toUpperCase()}`,
      username,
      target: 'cpns',
    })
    .eq('id', data.user.id);
  if (profileError) {
    throw new Error(`Unable to prepare smoke profile: ${profileError.message}`);
  }

  const client = createClient(supabaseUrl, publicKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: sessionData, error: signInError } =
    await client.auth.signInWithPassword({ email, password });
  if (signInError || !sessionData.session) {
    throw new Error(`Unable to sign in smoke user: ${signInError?.message}`);
  }
  return {
    userId: data.user.id,
    token: sessionData.session.access_token,
  };
}

async function connect(token, beforeConnect) {
  const socket = io(`${gameUrl}/match`, {
    transports: ['websocket'],
    auth: { token },
    autoConnect: false,
    forceNew: true,
    reconnection: false,
  });
  sockets.push(socket);
  const ready = event(socket, 'connection_success');
  const pending = beforeConnect?.(socket);
  socket.connect();
  await ready;
  return { socket, pending };
}

async function cleanup() {
  for (const socket of sockets) {
    socket.disconnect();
  }
  if (roomId) {
    await admin.from('match_results').delete().eq('room_id', roomId);
  }
  for (const userId of users) {
    await admin.from('coin_transactions').delete().eq('user_id', userId);
    await admin.auth.admin.deleteUser(userId);
  }
  gameServer?.kill();
}

function canConnect(port) {
  return new Promise((resolveConnection) => {
    const socket = createConnection({ host: '127.0.0.1', port });
    socket.once('connect', () => {
      socket.destroy();
      resolveConnection(true);
    });
    socket.once('error', () => resolveConnection(false));
  });
}

async function startGameServer() {
  if (process.env.GAME_SMOKE_EXTERNAL === 'true') return;
  const url = new URL(gameUrl);
  const port = Number(url.port || 80);
  if (await canConnect(port)) {
    throw new Error(`Smoke port ${port} is already in use.`);
  }
  gameServer = spawn(
    process.execPath,
    ['dist/main.js'],
    {
      cwd: projectDirectory,
      env: { ...process.env, PORT: String(port) },
      stdio: ['ignore', 'pipe', 'pipe'],
    },
  );
  const appendOutput = (chunk) => {
    serverOutput = `${serverOutput}${chunk}`.slice(-4_000);
  };
  gameServer.stdout.on('data', appendOutput);
  gameServer.stderr.on('data', appendOutput);

  for (let attempt = 0; attempt < 60; attempt += 1) {
    if (gameServer.exitCode != null) {
      throw new Error(
        `Game server exited with code ${gameServer.exitCode}: ${serverOutput}`,
      );
    }
    if (await canConnect(port)) return;
    await new Promise((resolveDelay) => setTimeout(resolveDelay, 250));
  }
  throw new Error(`Game server did not become ready: ${serverOutput}`);
}

try {
  await startGameServer();
  const [playerA, playerB] = await Promise.all([
    createSmokeUser('a'),
    createSmokeUser('b'),
  ]);
  const [{ socket: socketA }, { socket: socketB }] = await Promise.all([
    connect(playerA.token),
    connect(playerB.token),
  ]);

  const foundA = event(socketA, 'match_found');
  const foundB = event(socketB, 'match_found');
  const initialA = event(socketA, 'game_state_update');
  const initialB = event(socketB, 'game_state_update');
  socketA.emit('join_queue', { mode: 'ranked' });
  socketB.emit('join_queue', { mode: 'ranked' });

  const [matchA, matchB, stateA, stateB] = await Promise.all([
    foundA,
    foundB,
    initialA,
    initialB,
  ]);
  roomId = matchA.roomId;
  if (
    !roomId ||
    matchB.roomId !== roomId ||
    stateA.mode !== 'ranked' ||
    stateB.target !== 'cpns'
  ) {
    throw new Error('Matchmaking returned inconsistent room metadata.');
  }

  const card = stateA.self?.hand?.[0];
  if (!card?.id || !Array.isArray(card.options) || card.options.length === 0) {
    throw new Error('Initial server hand is unavailable.');
  }
  const opened = event(socketA, 'open_card_accepted');
  const openedState = event(socketA, 'game_state_update');
  socketA.emit('open_card', { roomId, cardId: card.id });
  await Promise.all([opened, openedState]);

  const played = event(socketA, 'play_card_result');
  const updated = event(socketA, 'game_state_update');
  socketA.emit('play_card', {
    roomId,
    cardId: card.id,
    selectedOptionIndex: 0,
  });
  const [playResult, nextState] = await Promise.all([played, updated]);
  if (
    playResult.actorUserId !== playerA.userId ||
    nextState.self.hand.some((item) => item.id === card.id)
  ) {
    throw new Error('Authoritative card resolution did not advance the hand.');
  }

  const offlinePresence = event(socketB, 'presence_update');
  socketA.disconnect();
  const offline = await offlinePresence;
  if (
    offline.players?.[playerA.userId]?.connected !== false ||
    !offline.players?.[playerA.userId]?.reconnectDeadline
  ) {
    throw new Error('Disconnect grace metadata was not emitted.');
  }

  const reconnect = await connect(playerA.token, (socket) => ({
    state: event(socket, 'game_state_update'),
    presence: event(socket, 'presence_update'),
  }));
  const [restored, online] = await Promise.all([
    reconnect.pending.state,
    reconnect.pending.presence,
  ]);
  if (
    restored.roomId !== roomId ||
    online.players?.[playerA.userId]?.connected !== true
  ) {
    throw new Error('Reconnect did not restore the active room.');
  }

  const resultA = event(reconnect.socket, 'match_result');
  const resultB = event(socketB, 'match_result');
  reconnect.socket.emit('surrender', { roomId });
  const [finalA, finalB] = await Promise.all([resultA, resultB]);
  if (
    finalA.reason !== 'surrender' ||
    finalB.roomId !== roomId ||
    finalA.mode !== 'ranked' ||
    finalA.target !== 'cpns' ||
    finalA.progressionPersisted !== true
  ) {
    throw new Error('Final authoritative result is incomplete.');
  }

  const { data: persisted, error: persistedError } = await admin
    .from('match_results')
    .select('id, mode, target, reason')
    .eq('room_id', roomId)
    .single();
  if (
    persistedError ||
    persisted?.mode !== 'ranked' ||
    persisted?.target !== 'cpns' ||
    persisted?.reason !== 'surrender'
  ) {
    throw new Error(
      `Match result was not persisted correctly: ${persistedError?.message}`,
    );
  }

  const { count: logCount, error: logError } = await admin
    .from('match_logs')
    .select('id', { count: 'exact', head: true })
    .eq('match_result_id', persisted.id);
  if (logError || !logCount || logCount < 3) {
    throw new Error(`Match logs were not persisted: ${logError?.message}`);
  }

  console.log(
    JSON.stringify({
      ok: true,
      matchmaking: 'ranked/cpns',
      cardResolved: true,
      reconnectRestored: true,
      resultPersisted: true,
      logCount,
    }),
  );
} finally {
  await cleanup();
}
