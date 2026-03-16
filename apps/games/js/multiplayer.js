// ============================================================
//  multiplayer.js  –  PeerJS wrapper for VS Player mode
// ============================================================

const Multiplayer = (() => {
  let peer = null;
  let conn = null;
  let _isHost = false;
  let _onMessage = null;
  let _onConnected = null;
  let _onDisconnected = null;

  const CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  function genCode(len = 6) {
    let s = '';
    for (let i = 0; i < len; i++) s += CHARS[Math.floor(Math.random() * CHARS.length)];
    return s;
  }

  function createRoom(onCode, onConnected, onMessage, onDisconnected) {
    _isHost = true;
    _onMessage = onMessage;
    _onConnected = onConnected;
    _onDisconnected = onDisconnected;

    const code = genCode(6);
    const peerId = 'WBRL_' + code;

    peer = new Peer(peerId, { debug: 1 });

    peer.on('open', () => {
      if (onCode) onCode(code);
    });

    peer.on('connection', (c) => {
      conn = c;
      _setupConn();
    });

    peer.on('error', (err) => {
      console.warn('PeerJS host error:', err);
      document.getElementById('room-status').textContent = '❌ Connection error: ' + err.type;
    });
  }

  function joinRoom(code, onConnected, onMessage, onDisconnected) {
    _isHost = false;
    _onMessage = onMessage;
    _onConnected = onConnected;
    _onDisconnected = onDisconnected;

    const myId = 'WBRL_G_' + genCode(8);
    peer = new Peer(myId, { debug: 1 });

    peer.on('open', () => {
      conn = peer.connect('WBRL_' + code.toUpperCase().trim(), { reliable: true });
      _setupConn();
    });

    peer.on('error', (err) => {
      console.warn('PeerJS join error:', err);
      const el = document.getElementById('join-status');
      if (el) el.textContent = '❌ ' + (err.type === 'peer-unavailable'
        ? 'Room not found. Check the code.'
        : 'Connection error: ' + err.type);
    });
  }

  function _setupConn() {
    conn.on('open', () => {
      if (_onConnected) _onConnected();
    });
    conn.on('data', (data) => {
      if (_onMessage) _onMessage(data);
    });
    conn.on('close', () => {
      if (_onDisconnected) _onDisconnected();
    });
    conn.on('error', (err) => {
      console.warn('Conn error:', err);
    });
  }

  function send(data) {
    if (conn && conn.open) {
      try { conn.send(data); } catch (e) { console.warn('Send error:', e); }
    }
  }

  function close() {
    if (conn) { try { conn.close(); } catch(_) {} }
    if (peer) { try { peer.destroy(); } catch(_) {} }
    conn = null; peer = null;
  }

  function isConnected() {
    return !!(conn && conn.open);
  }

  return {
    createRoom, joinRoom, send, close, isConnected,
    get isHost() { return _isHost; }
  };
})();
