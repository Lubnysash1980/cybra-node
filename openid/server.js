require("dotenv").config();

const express = require("express");
const jwt = require("jsonwebtoken");
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");
const rateLimit = require("express-rate-limit");

const app = express();
app.disable("x-powered-by");

const PORT = Number(process.env.PORT || 8787);
const DB = path.join(__dirname, "data/users.json");
const JWT_SECRET = process.env.JWT_SECRET;
const CLIENT_ID = process.env.GITHUB_CLIENT_ID;
const CLIENT_SECRET = process.env.GITHUB_CLIENT_SECRET;
const BASE_URL = process.env.BASE_URL;

if (!JWT_SECRET || JWT_SECRET.length < 32 ||
    !CLIENT_ID || !CLIENT_SECRET || !BASE_URL) {
  console.error("CYBRA OPEN ID: configure .env first");
  process.exit(1);
}

fs.mkdirSync(path.dirname(DB), { recursive: true });
if (!fs.existsSync(DB)) fs.writeFileSync(DB, "[]");

app.use(express.json());

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 60,
  standardHeaders: true,
  legacyHeaders: false
});
app.use(limiter);

const secure = BASE_URL.startsWith("https://");

function cookie(name, value, maxAge) {
  return `${name}=${value}; HttpOnly; SameSite=Lax; Path=/; Max-Age=${maxAge}${secure ? "; Secure" : ""}`;
}

function getCookie(req, name) {
  const raw = req.headers.cookie || "";
  const item = raw.split(";").map(x => x.trim())
    .find(x => x.startsWith(name + "="));
  return item ? item.slice(name.length + 1) : "";
}

function signState(state) {
  const sig = crypto.createHmac("sha256", JWT_SECRET)
    .update(state).digest("hex");
  return `${state}.${sig}`;
}

function verifyState(value) {
  const parts = value.split(".");
  if (parts.length !== 2) return false;
  const expected = signState(parts[0]);
  return crypto.timingSafeEqual(
    Buffer.from(value),
    Buffer.from(expected)
  );
}

function loadUsers() {
  return JSON.parse(fs.readFileSync(DB, "utf8"));
}

function saveUsers(users) {
  const tmp = DB + ".tmp";
  fs.writeFileSync(tmp, JSON.stringify(users, null, 2), { mode: 0o600 });
  fs.renameSync(tmp, DB);
}

function auth(req, res, next) {
  const token = getCookie(req, "cybra_session");
  try {
    if (!token) throw new Error("No session");
    req.user = jwt.verify(token, JWT_SECRET);
    next();
  } catch {
    res.status(401).json({ error: "Authentication required" });
  }
}

app.get("/health", (req, res) => {
  res.json({ service: "CYBRA OPEN ID", status: "online" });
});

app.get("/auth/github", (req, res) => {
  const state = crypto.randomBytes(32).toString("hex");
  res.setHeader("Set-Cookie", cookie("cybra_oauth_state", signState(state), 600));

  const url = new URL("https://github.com/login/oauth/authorize");
  url.searchParams.set("client_id", CLIENT_ID);
  url.searchParams.set("redirect_uri", BASE_URL + "/auth/github/callback");
  url.searchParams.set("scope", "read:user user:email");
  url.searchParams.set("state", state);

  res.redirect(url.toString());
});

app.get("/auth/github/callback", async (req, res) => {
  try {
    const stateCookie = getCookie(req, "cybra_oauth_state");
    const state = req.query.state;

    if (!state || !stateCookie ||
        !verifyState(stateCookie) ||
        stateCookie.split(".")[0] !== state) {
      return res.status(403).send("Invalid OAuth state");
    }

    res.setHeader("Set-Cookie", cookie("cybra_oauth_state", "", 0));

    if (!req.query.code) {
      return res.status(400).send("Missing OAuth code");
    }

    const tokenResponse = await fetch(
      "https://github.com/login/oauth/access_token",
      {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          client_id: CLIENT_ID,
          client_secret: CLIENT_SECRET,
          code: req.query.code
        })
      }
    );

    const tokenData = await tokenResponse.json();
    if (!tokenData.access_token) {
      return res.status(401).send("GitHub authorization failed");
    }

    const githubResponse = await fetch("https://api.github.com/user", {
      headers: {
        Authorization: `Bearer ${tokenData.access_token}`,
        Accept: "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "CYBRA-OPEN-ID"
      }
    });

    if (!githubResponse.ok) {
      return res.status(401).send("Cannot verify GitHub account");
    }

    const gh = await githubResponse.json();
    const now = new Date().toISOString();
    const users = loadUsers();

    let user = users.find(u => u.github_id === gh.id);

    if (!user) {
      user = {
        id: crypto.randomUUID(),
        github_id: gh.id,
        login: gh.login,
        avatar: gh.avatar_url,
        profile_url: gh.html_url,
        created_at: now,
        last_login: now
      };
      users.push(user);
    } else {
      user.login = gh.login;
      user.avatar = gh.avatar_url;
      user.profile_url = gh.html_url;
      user.last_login = now;
    }

    saveUsers(users);

    const session = jwt.sign({
      sub: user.id,
      github_id: user.github_id,
      login: user.login
    }, JWT_SECRET, { expiresIn: "12h", issuer: "cybra-open-id" });

    res.setHeader("Set-Cookie", cookie("cybra_session", session, 43200));
    res.redirect("/");

  } catch (error) {
    console.error("OAuth error:", error.message);
    res.status(500).send("CYBRA authorization error");
  }
});

app.get("/api/me", auth, (req, res) => {
  const user = loadUsers().find(u => u.id === req.user.sub);
  if (!user) return res.status(404).json({ error: "User not found" });
  res.json({ authenticated: true, user });
});

app.post("/auth/logout", (req, res) => {
  res.setHeader("Set-Cookie", cookie("cybra_session", "", 0));
  res.json({ status: "logged_out" });
});

app.get("/", (req, res) => {
  res.type("html").send(`
    <!doctype html>
    <html>
    <head><meta charset="utf-8"><title>CYBRA OPEN ID</title></head>
    <body>
      <h1>CYBRA OPEN ID</h1>
      <a href="/auth/github">Увійти через GitHub</a>
      <p><a href="/api/me">Мій профіль</a></p>
      <button onclick="fetch('/auth/logout',{method:'POST'}).then(()=>location.reload())">
        Вийти
      </button>
    </body>
    </html>
  `);
});

app.listen(PORT, "127.0.0.1", () => {
  console.log(`CYBRA OPEN ID listening on 127.0.0.1:${PORT}`);
});
