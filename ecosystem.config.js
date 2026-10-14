{
  name: "cybra-autogit",
  script: "/data/data/com.termux/files/home/CYBRA/bin/cybra_autogit.sh",
  interpreter: "bash",
  cwd: "/data/data/com.termux/files/home/CYBRA",
  cron_restart: "*/15 * * * *",  // кожні 15 хв
  autorestart: false
}
