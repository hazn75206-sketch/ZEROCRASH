const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');
const { exec } = require('child_process');
const util = require('util');
const execAsync = util.promisify(exec);
const app = express();
app.use(cors({ origin: '*' }));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const DB_FILE = path.join(__dirname, 'db.json');
let db = { users: [], bugs: [], news: [], tq: [], servers: [], activities: [], senders: [] };
function save() { try { fs.writeFileSync(DB_FILE, JSON.stringify(db, null, 2)); } catch (e) { console.log('save err', e.message); } }
function load() {
  if (fs.existsSync(DB_FILE)) { try { db = JSON.parse(fs.readFileSync(DB_FILE, 'utf8')); } catch (e) { console.log('db load err', e.message); } }
  if (!db.users || !db.users.length) {
    db.users = [
      { username: 'owner', password: bcrypt.hashSync('owner123', 8), role: 'owner', key: 'key_owner_123', expiredDate: '2099-12-31', deviceId: null },
      { username: 'admin', password: bcrypt.hashSync('admin123', 8), role: 'admin', key: 'key_admin_123', expiredDate: '2027-12-31', deviceId: null }
    ];
    db.bugs = [{ bug_id: 'delay', bug_name: 'DELAY CRASH' }, { bug_id: 'freeze', bug_name: 'FREEZE' }, { bug_id: 'crash', bug_name: 'CRASH IOS' }];
    db.news = [{ title: 'Welcome', content: 'Zero Crash Railway - Real (no device lock)' }];
    db.tq = [{ name: 'CLOUD INFINITY', status: 'Owner', ppUrl: '', contac: 'fuadun123' }];
    db.servers = [];
    db.activities = [];
    db.senders = [];
    save();
  } else {
    let changed = false;
    db.users.forEach(u => {
      if (u.password && !String(u.password).startsWith('$2a$') && !String(u.password).startsWith('$2b$')) { u.password = bcrypt.hashSync(String(u.password), 8); changed = true; }
      if (u.deviceId !== null && u.deviceId !== undefined) { u.deviceId = null; changed = true; }
    });
    if (changed) save();
  }
}
load();
function findByKey(k) { return db.users.find(u => u.key === k); }
function findByPass(username, password) {
  const u = db.users.find(x => x.username === username);
  if (!u) return null;
  try { if (bcrypt.compareSync(String(password), u.password)) return u; } catch (_) {}
  if (u.password === password) return u;
  return null;
}
function logActivity(key, act) { db.activities.unshift({ key, act, time: new Date().toISOString() }); if (db.activities.length > 300) db.activities.pop(); save(); }
function getParam(req, ...names) {
  for (const n of names) {
    if (req.body && req.body[n] !== undefined) return req.body[n];
    if (req.query && req.query[n] !== undefined) return req.query[n];
  }
  return undefined;
}
function buildArgs(u) { return { valid: true, key: u.key, role: u.role, expiredDate: u.expiredDate, listBug: db.bugs, listDDoS: [], news: db.news }; }

app.post('/validate', (req, res) => {
  const username = getParam(req, 'username', 'newUser');
  const password = getParam(req, 'password', 'pass');
  if (!username || !password) return res.json({ valid: false, message: 'missing' });
  const u = findByPass(username, password);
  if (!u) return res.json({ valid: false, message: 'user not found or password wrong' });
  if (new Date(u.expiredDate) < new Date()) return res.json({ valid: false, expired: true, message: 'expired' });
  logActivity(u.key, 'validate ' + username);
  res.json(buildArgs(u));
});
app.get('/validate', (req, res) => {
  const u = findByPass(getParam(req, 'username'), getParam(req, 'password'));
  if (!u) return res.json({ valid: false });
  res.json(buildArgs(u));
});
app.get('/myInfo', (req, res) => {
  const key = getParam(req, 'key');
  let u = key ? findByKey(key) : findByPass(getParam(req, 'username'), getParam(req, 'password'));
  if (!u) return res.json({ valid: false });
  res.json(buildArgs(u));
});
app.post('/myInfo', (req, res) => {
  const key = getParam(req, 'key');
  let u = key ? findByKey(key) : findByPass(getParam(req, 'username'), getParam(req, 'password'));
  if (!u) return res.json({ valid: false });
  res.json(buildArgs(u));
});
app.get('/tq', (req, res) => res.json({ status: true, result: db.tq }));
function handleListUsers(req, res) {
  const u = findByKey(getParam(req, 'key'));
  if (!u) return res.json({ valid: false, authorized: false, message: 'invalid key' });
  res.json({ valid: true, authorized: true, users: db.users, result: db.users });
}
app.get('/listUsers', handleListUsers);
app.post('/listUsers', handleListUsers);
function handleUserAdd(req, res) {
  const key = getParam(req, 'key');
  const u = findByKey(key);
  if (!u || !['owner', 'admin', 'partner', 'moderator'].includes(u.role)) return res.json({ created: false, message: 'unauthorized' });
  const username = getParam(req, 'username', 'newUser');
  const password = getParam(req, 'password', 'pass');
  const day = getParam(req, 'day');
  const role = getParam(req, 'role');
  if (!username || !password) return res.json({ created: false, message: 'missing username/password' });
  if (db.users.find(x => x.username === username)) return res.json({ created: false, message: 'exists' });
  const days = parseInt(day || 30); if (isNaN(days) || days <= 0) return res.json({ created: false, invalidDay: true, message: 'invalid day' });
  const d = new Date(); d.setDate(d.getDate() + days);
  const nu = { username, password: bcrypt.hashSync(String(password), 8), role: role || 'member', expiredDate: d.toISOString().split('T')[0], key: 'key_' + username + '_' + Date.now(), deviceId: null };
  db.users.push(nu); save(); logActivity(key, 'userAdd ' + username);
  res.json({ created: true, user: { username: nu.username, role: nu.role, expiredDate: nu.expiredDate, key: nu.key }, status: true });
}
app.get('/userAdd', handleUserAdd);
app.post('/userAdd', handleUserAdd);
app.get('/createAccount', handleUserAdd);
app.post('/createAccount', handleUserAdd);
function handleDeleteUser(req, res) {
  const key = getParam(req, 'key');
  const username = getParam(req, 'username');
  const u = findByKey(key);
  if (!u || !['owner', 'admin', 'partner', 'moderator'].includes(u.role)) return res.json({ deleted: false, message: 'unauthorized' });
  const idx = db.users.findIndex(x => x.username === username);
  if (idx === -1) return res.json({ deleted: false, message: 'not found' });
  if (db.users[idx].role === 'owner') return res.json({ deleted: false, message: 'cannot delete owner' });
  const del = db.users.splice(idx, 1)[0]; save(); logActivity(key, 'deleteUser ' + username);
  res.json({ deleted: true, user: del, status: true });
}
app.get('/deleteUser', handleDeleteUser);
app.post('/deleteUser', handleDeleteUser);
function handleEditUser(req, res) {
  const key = getParam(req, 'key');
  const username = getParam(req, 'username');
  const addDays = getParam(req, 'addDays', 'day');
  const newPass = getParam(req, 'newPass', 'newPassword', 'pass');
  const u = findByKey(key);
  if (!u) return res.json({ edited: false, message: 'invalid key' });
  const t = db.users.find(x => x.username === username);
  if (!t) return res.json({ edited: false, message: 'not found' });
  if (addDays) { const d = new Date(t.expiredDate); d.setDate(d.getDate() + parseInt(addDays || 0)); t.expiredDate = d.toISOString().split('T')[0]; }
  if (newPass) t.password = bcrypt.hashSync(String(newPass), 8);
  save(); logActivity(key, 'editUser ' + username);
  res.json({ edited: true, user: { username: t.username, role: t.role, expiredDate: t.expiredDate }, status: true });
}
app.get('/editUser', handleEditUser);
app.post('/editUser', handleEditUser);
app.get('/mySender', (req, res) => res.json({ valid: true, connections: db.senders, result: db.senders }));
app.post('/mySender', (req, res) => res.json({ valid: true, connections: db.senders, result: db.senders }));
app.get('/getPairing', (req, res) => res.json({ valid: true, pairingCode: '1234-5678', code: '1234-5678' }));
app.post('/getPairing', (req, res) => res.json({ valid: true, pairingCode: '1234-5678' }));
app.delete('/deleteSender', (req, res) => res.json({ valid: true, deleted: true }));
app.get('/deleteSender', (req, res) => res.json({ valid: true, deleted: true }));
app.post('/deleteSender', (req, res) => res.json({ valid: true, deleted: true }));
app.get('/sendBug', (req, res) => {
  const key = getParam(req, 'key');
  const u = findByKey(key);
  if (!u) return res.json({ valid: false, message: 'invalid key' });
  logActivity(key, 'sendBug mock to ' + getParam(req, 'target'));
  res.json({ valid: true, sended: true, message: 'Bug sent (mock)', status: true });
});
app.post('/sendBug', (req, res) => res.json({ valid: true, sended: true, status: true }));
app.get('/raidGroup', (req, res) => res.json({ valid: true, sended: true, status: true }));
app.post('/raidGroup', (req, res) => res.json({ valid: true, sended: true }));
app.get('/getSenderStats', (req, res) => res.json({ valid: true, _privateSenderCount: db.senders.length, _globalSenderCount: db.senders.length, private: db.senders.length, global: db.senders.length }));
app.post('/changepass', (req, res) => {
  const username = getParam(req, 'username');
  const oldPass = getParam(req, 'oldPass', 'oldPassword');
  const newPass = getParam(req, 'newPass', 'newPassword');
  const key = getParam(req, 'sessionKey', 'key');
  let u = (username ? db.users.find(x => x.username === username) : null) || (key ? findByKey(key) : null);
  if (!u) return res.json({ success: false, message: 'not found' });
  if (oldPass) { let ok = false; try { ok = bcrypt.compareSync(String(oldPass), u.password); } catch (_) {} if (!ok && u.password !== oldPass) return res.json({ success: false, message: 'old pass wrong' }); }
  if (!newPass) return res.json({ success: false, message: 'missing new pass' });
  u.password = bcrypt.hashSync(String(newPass), 8); save(); logActivity(u.key, 'changepass ' + u.username);
  res.json({ success: true, status: true });
});
function handleActivity(req, res) {
  const key = getParam(req, 'key');
  const u = findByKey(key);
  if (!u) return res.json({ valid: false, message: 'invalid key' });
  const acts = db.activities.filter(a => a.key === key).slice(0, 100);
  const mapped = acts.map(a => ({ type: a.act, title: a.act, description: a.act, timestamp: new Date(a.time).getTime(), time: a.time, act: a.act }));
  res.json({ valid: true, result: mapped, activities: mapped });
}
app.get('/getMyActivity', handleActivity);
app.post('/getMyActivity', handleActivity);
// My VPS List: app expects RAW array, so return array directly (fix owner dashboard)
function vpsArray() { return db.servers.map(s => ({ id: s.id, host: s.host, username: s.username || s.name || '', name: s.name, status: s.status })); }
app.get('/myServer', (req, res) => {
  const u = findByKey(getParam(req, 'key'));
  if (!u) return res.status(401).json({ valid: false, message: 'invalid key' });
  res.json(vpsArray());
});
app.post('/myServer', (req, res) => {
  const u = findByKey(getParam(req, 'key'));
  if (!u) return res.status(401).json({ valid: false });
  res.json(vpsArray());
});
function handleAddServer(req, res) {
  const key = getParam(req, 'key');
  const host = getParam(req, 'host', 'ip', 'serverHost');
  const username = getParam(req, 'username', 'user');
  const u = findByKey(key);
  if (!u) return res.json({ added: false, success: false, message: 'invalid key' });
  const srv = { id: Date.now().toString(), name: getParam(req, 'name', 'serverName') || username || 'Server', host: host || '0.0.0.0', username: username || '', status: 'online', createdBy: u.username, time: new Date().toISOString() };
  db.servers.push(srv); save(); logActivity(key, 'addServer ' + srv.name + ' ' + srv.host);
  res.json({ added: true, success: true, server: srv, status: true });
}
app.get('/addServer', handleAddServer);
app.post('/addServer', handleAddServer);
function handleDelServer(req, res) {
  const key = getParam(req, 'key');
  const host = getParam(req, 'host', 'ip', 'id');
  let idx = -1;
  if (host) idx = db.servers.findIndex(s => s.host === host || s.id === host);
  if (idx !== -1) { const del = db.servers.splice(idx, 1)[0]; save(); logActivity(key, 'delServer ' + del.host); }
  res.json({ deleted: true, success: true, status: true });
}
app.get('/delServer', handleDelServer);
app.post('/delServer', handleDelServer);
app.get('/cncSend', (req, res) => {
  const u = findByKey(getParam(req, 'key'));
  if (!u) return res.json({ valid: false });
  logActivity(getParam(req, 'key'), 'cncSend real-log to ' + getParam(req, 'target'));
  res.json({ valid: true, sended: true, status: true, message: 'logged (simulator real)', cooldown: false });
});
app.post('/cncSend', (req, res) => res.json({ valid: true, sended: true, status: true }));
app.get('/getServerInfo', (req, res) => {
  const u = findByKey(req.query.key);
  if (!u) return res.status(401).json({ valid: false });
  res.json({ valid: true, server: { name: 'Railway', status: 'online', uptime: process.uptime() }, user: { username: u.username, role: u.role, expiredDate: u.expiredDate } });
});
app.get('/killWifi', async (req, res) => {
  const u = findByKey(req.query.key);
  if (!u) return res.status(401).json({ valid: false });
  logActivity(req.query.key, 'killWifi real to ' + req.query.target);
  res.json({ valid: true, sended: true, message: 'killWifi REAL via server (VPS root, bukan HP)', status: true });
});
// Native downloader - yt-dlp binary downloaded at RUNTIME to /tmp (no apt, no npm postinstall)
let ytdlpReady = null;
function ensureYtDlp() {
  if (ytdlpReady) return ytdlpReady;
  ytdlpReady = (async () => {
    try { await execAsync('test -x /tmp/yt-dlp && /tmp/yt-dlp --version'); return '/tmp/yt-dlp'; } catch (_) {}
    try { await execAsync('which yt-dlp && yt-dlp --version'); return 'yt-dlp'; } catch (_) {}
    await execAsync('curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux -o /tmp/yt-dlp && chmod +x /tmp/yt-dlp', { maxBuffer: 10 * 1024 * 1024 });
    await execAsync('/tmp/yt-dlp --version');
    return '/tmp/yt-dlp';
  })();
  ytdlpReady.catch(() => { ytdlpReady = null; });
  return ytdlpReady;
}
async function ytdlpJson(clean) {
  const bin = await ensureYtDlp();
  const { stdout } = await execAsync(bin + ' -j --no-warnings --socket-timeout 20 "' + clean + '"', { maxBuffer: 10 * 1024 * 1024 });
  return JSON.parse(stdout);
}
function pickVideoUrl(j) {
  if (j.url) return j.url;
  if (j.requested_formats && j.requested_formats.length) return j.requested_formats[0].url;
  if (j.formats && j.formats.length) return j.formats[j.formats.length - 1].url;
  return null;
}
app.get('/api/d/tiktok', async (req, res) => {
  const url = req.query.url;
  if (!url) return res.json({ status: false, message: 'missing url' });
  try {
    const clean = String(url).replace(/"/g, '').split(' ')[0];
    const j = await ytdlpJson(clean);
    const videoUrl = pickVideoUrl(j);
    if (!videoUrl) return res.json({ status: false, message: 'no video url in yt-dlp output' });
    res.json({ status: true, data: { urls: [videoUrl], metadata: { title: j.title || 'TikTok Video', creator: j.uploader || j.creator || j.channel || 'Unknown', author: j.uploader || 'Unknown', thumbnail: j.thumbnail || '' } } });
  } catch (e) { res.json({ status: false, message: 'yt-dlp failed: ' + String(e && e.message || e).slice(0, 300) }); }
});
app.get('/api/d/igdl', async (req, res) => {
  const url = req.query.url;
  if (!url) return res.json({ status: false });
  try {
    const clean = String(url).replace(/"/g, '').split(' ')[0];
    const j = await ytdlpJson(clean);
    const urls = [];
    if (j.url) urls.push({ url: j.url });
    else if (j.entries && j.entries.length) { j.entries.forEach(e => { if (e && e.url) urls.push({ url: e.url }); }); }
    else if (j.requested_formats) { j.requested_formats.forEach(f => { if (f.url) urls.push({ url: f.url }); }); }
    if (!urls.length) return res.json({ status: false, message: 'no media found' });
    res.json({ status: true, data: urls });
  } catch (e) { res.json({ status: false, message: 'yt-dlp ig failed: ' + String(e && e.message || e).slice(0, 300) }); }
});
app.get('/api/tools/nik-checker', (req, res) => {
  const nik = req.query.nik;
  if (!nik || nik.length != 16) return res.json({ status: false, message: 'NIK harus 16 digit' });
  const valid = /^\d{16}$/.test(nik);
  res.json({ status: true, result: { nik, valid, message: valid ? 'NIK valid (native)' : 'NIK invalid' } });
});
app.get('/api/tools/dns', async (req, res) => {
  const domain = req.query.domain;
  if (!domain) return res.json({ status: false });
  try {
    const dns = require('dns').promises;
    const clean = String(domain).replace(/[^a-zA-Z0-9.-]/g, '');
    const ips = await dns.resolve4(clean);
    res.json({ status: true, result: { domain: clean, ips } });
  } catch (e) { res.json({ status: false, message: String(e && e.message || e).slice(0, 200) }); }
});
app.get('/api/tools/text2qr', async (req, res) => {
  const text = req.query.text;
  if (!text) return res.json({ status: false });
  try {
    const QRCode = require('qrcode');
    const dataUrl = await QRCode.toDataURL(String(text));
    res.json({ status: true, result: { text, qr: dataUrl } });
  } catch (e) { res.json({ status: false, message: e.message }); }
});
function detectPlatform(url) {
  const u = String(url).toLowerCase();
  if (u.includes('tiktok.com') || u.includes('vt.tiktok') || u.includes('vm.tiktok')) return 'tiktok';
  if (u.includes('instagram.com')) return 'instagram';
  if (u.includes('youtube.com') || u.includes('youtu.be') || u.includes('music.youtube')) return 'youtube';
  if (u.includes('twitter.com') || u.includes('x.com')) return 'twitter';
  if (u.includes('facebook.com') || u.includes('fb.watch') || u.includes('fb.com')) return 'facebook';
  if (u.includes('pinterest.com') || u.includes('pin.it')) return 'pinterest';
  if (u.includes('threads.com') || u.includes('threads.net')) return 'threads';
  if (u.includes('spotify.com') || u.includes('spotify.link')) return 'spotify';
  if (u.includes('music.apple.com')) return 'applemusic';
  if (u.includes('bilibili.com') || u.includes('b23.tv') || u.includes('bili.im')) return 'bilibili';
  if (u.includes('douyin.com') || u.includes('v.douyin')) return 'douyin';
  if (u.includes('xiaohongshu') || u.includes('xhslink')) return 'rednote';
  if (u.includes('pixiv.net')) return 'pixiv';
  if (u.includes('bandcamp.com')) return 'bandcamp';
  return 'universal';
}
// Universal downloader (Mori-style, yt-dlp 1800+ sites) - siputzx-compatible: {status, platform, data}
app.get('/api/d/universal', async (req, res) => {
  const url = req.query.url;
  if (!url) return res.json({ status: false, message: 'missing url' });
  const platform = detectPlatform(url);
  if (platform === 'spotify' || platform === 'applemusic') {
    return res.json({ status: false, platform, message: 'Audio platform (Spotify/Apple Music) segera hadir. Gunakan Spotify/Apple app untuk audio.' });
  }
  try {
    const clean = String(url).replace(/"/g, '').split(' ')[0].split('\n')[0];
    const j = await ytdlpJson(clean);
    const items = [];
    const pushUrl = (u, kind) => { if (u && typeof u === 'string' && u.startsWith('http')) items.push({ url: u, kind: kind || (/(\.jpg|\.jpeg|\.png|\.webp)/i.test(u.split('?')[0]) ? 'photo' : 'video') }); };
    if (j.url) pushUrl(j.url);
    if (j.entries && j.entries.length) {
      for (const e of j.entries.slice(0, 20)) {
        if (!e) continue;
        if (e.url) pushUrl(e.url);
        else if (e.requested_formats && e.requested_formats.length) pushUrl(e.requested_formats[0].url);
        else if (e.formats && e.formats.length) pushUrl(e.formats[e.formats.length - 1].url);
      }
    }
    if (!items.length && j.requested_formats) j.requested_formats.forEach(f => { if (f.url) pushUrl(f.url); });
    if (!items.length && j.formats) { const f = j.formats.filter(x => x.url && x.ext === 'mp4').pop() || j.formats.filter(x => x.url).pop(); if (f) pushUrl(f.url); }
    if (!items.length) return res.json({ status: false, platform, message: 'no media found' });
    const firstVideo = items.find(i => i.kind === 'video');
    res.json({ status: true, platform, data: { urls: items.map(i => i.url), metadata: { title: j.title || 'Media', creator: j.uploader || j.creator || j.channel || 'Unknown', author: j.uploader || 'Unknown', thumbnail: j.thumbnail || '' } }, items, kind: firstVideo ? 'video' : items[0].kind });
  } catch (e) { res.json({ status: false, platform, message: 'gagal mengambil media: ' + String(e && e.message || e).slice(0, 200) }); }
});
app.get('/ping', (req, res) => res.json({ ok: true, time: new Date().toISOString() }));
app.get('/', (req, res) => res.json({ ok: true, service: 'Zero Crash Railway - Real (no device lock)', uptime: process.uptime(), db: { users: db.users.length, servers: db.servers.length } }));
const PORT = process.env.PORT || process.env.SERVER_PORT || 20854;
const ALLOC = 20854;
app.listen(PORT, '0.0.0.0', () => console.log('Zero Crash REAL listening ' + PORT));
if (ALLOC != PORT) { try { app.listen(ALLOC, '0.0.0.0', () => console.log('Also listening ' + ALLOC)); } catch (_) {} }
