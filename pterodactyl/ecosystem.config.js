module.exports = {
  apps: [{
    name: "private-server",
    script: "index.js",
    // ganti index.js sesuai entry private-server banditflow (ada yang app.js / server.js)
    instances: 1,
    exec_mode: "fork",
    watch: false,
    autorestart: true,
    max_memory_restart: "900M",
    env: {
      NODE_ENV: "production",
      PORT: "2014",
      // tambah env private-server kamu di sini
      // KEY_SECRET: "xxx"
    }
  }]
};
