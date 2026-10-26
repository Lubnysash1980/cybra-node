#!/usr/bin/env python3
"""CYBRA Taxi API v1.0 — FastAPI wrapper для 60+ модулів.
   Swagger: http://localhost:8000/docs
   Auth: Bearer JWT (HS256)
"""
import os, sys, json, time, hmac, hashlib, subprocess, secrets
from pathlib import Path
from datetime import datetime, timezone, timedelta
from typing import Optional, List

from fastapi import FastAPI, HTTPException, Depends, Header, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, Field
import jwt
from jwt.exceptions import InvalidTokenError as JWTError
import redis

# ─── config ───
CYBRA = Path(os.environ.get("CYBRA", Path.home()/"CYBRA"))
REDIS_HOST = os.environ.get("REDIS_HOST", "127.0.0.1")
REDIS_PORT = int(os.environ.get("REDIS_PORT", 6379))
JWT_SECRET = os.environ.get("CYBRA_JWT_SECRET") or secrets.token_hex(32)
JWT_ALGO = "HS256"
JWT_EXPIRE_HOURS = 24*7
TOKEN_CYBRA = "0x74dA52028E42A37bc89E05c2fD5c52daBE4CB48f"
COMMISSION_PCT = 5

r = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, decode_responses=True)

# ─── app ───
app = FastAPI(
    title="CYBRA Taxi API",
    version="1.0",
    description="REST для Flutter (rider/driver). Backend: 60+ shell modules 200-272.",
    docs_url="/docs",
    redoc_url="/redoc",
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)
bearer = HTTPBearer(auto_error=False)

# ═══════════════ AUTH ═══════════════
def hash_phone(phone: str) -> str:
    return hashlib.sha256(f"{phone}:{JWT_SECRET}".encode()).hexdigest()[:16]

def make_jwt(phone: str, role: str = "rider") -> str:
    payload = {
        "sub": phone,
        "role": role,
        "iat": int(time.time()),
        "exp": int(time.time()) + JWT_EXPIRE_HOURS*3600,
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGO)

async def current_user(cred: Optional[HTTPAuthorizationCredentials] = Depends(bearer)) -> dict:
    if not cred:
        raise HTTPException(401, "no bearer token")
    try:
        payload = jwt.decode(cred.credentials, JWT_SECRET, algorithms=[JWT_ALGO])
    except JWTError as e:
        raise HTTPException(401, f"bad token: {e}")
    return payload

def require_role(*allowed):
    async def check(user: dict = Depends(current_user)):
        if user.get("role") not in allowed:
            raise HTTPException(403, f"need role: {allowed}")
        return user
    return check

# ═══════════════ HELPERS ═══════════════
def now_iso(): return datetime.now(timezone.utc).isoformat()
def gen_id(prefix): return f"{prefix}-{int(time.time())}-{secrets.token_hex(4)}"

def call_module(n: int, *args, timeout: int = 20):
    for pat in (f"module_{n:03d}_*", f"module_{n}_*"):
        dirs = list((CYBRA/"modules").glob(pat))
        if dirs:
            main = dirs[0]/"main.sh"
            if main.exists():
                try:
                    res = subprocess.run(["bash", str(main), *map(str, args)],
                                         capture_output=True, text=True, timeout=timeout, input="")
                    return {"rc": res.returncode, "stdout": res.stdout, "stderr": res.stderr}
                except subprocess.TimeoutExpired:
                    return {"rc": 124, "error": "timeout"}
    return {"rc": 127, "error": f"module {n} not found"}

def push_event(etype: str, data: dict, src: str = "api"):
    ev = {"id": gen_id("EV"), "type": etype, "data": data, "src": src, "ts": now_iso()}
    r.rpush("cybra:taxi:events", json.dumps(ev, ensure_ascii=False))
    return ev["id"]

# ═══════════════ MODELS ═══════════════
class RegisterIn(BaseModel):
    phone: str = Field(..., min_length=5, max_length=20)
    role: str = Field("rider", regex="^(rider|driver|both)$")

class LoginIn(BaseModel):
    phone: str
    code: str = Field(..., min_length=4)

class RideIn(BaseModel):
    pickup: str
    dropoff: str
    km: float = 5.0
    price: Optional[float] = None
    pickup_lat: Optional[float] = None
    pickup_lon: Optional[float] = None

class MarkerIn(BaseModel):
    id: str
    lat: float
    lon: float
    note: str = "order"

class ZoneIn(BaseModel):
    id: str
    lat: float
    lon: float
    radius: int = 200
    reason: str = "residential"

class WalletIn(BaseModel):
    address: str = Field(..., regex="^0x[a-fA-F0-9]{40}$")
    role: str = Field("rider", regex="^(rider|driver|both)$")

class PriceOfferIn(BaseModel):
    ride_id: str
    amount: float

class PriceAcceptIn(BaseModel):
    ride_id: str
    who: str = "client"

class PerKmIn(BaseModel):
    who: str = Field("client", regex="^(client|driver)$")
    price: float

class InterestsIn(BaseModel):
    who: str
    tags: List[str] = Field(..., min_length=1)

class MatchIn(BaseModel):
    rider_id: str

class CommissionIn(BaseModel):
    amount: float
    ride_id: Optional[str] = None

class InstantIn(BaseModel):
    from_addr: str = Field(..., alias="from")
    to_addr: str = Field(..., alias="to")
    amount: float
    class Config: allow_population_by_field_name = True

class ContractIn(BaseModel):
    amount: float
    driver: str
    rider: str

class RatingIn(BaseModel):
    who: str
    score: int = Field(..., ge=1, le=5)
    comment: str = ""

class I18nIn(BaseModel):
    lang: str = Field(..., regex="^(en|uk|es|de|fr|ar|zh)$")

class EventIn(BaseModel):
    type: str
    data: dict = {}
    src: str = "api"

# ═══════════════ HEALTH ═══════════════
@app.get("/api/health", tags=["system"])
def health():
    try:
        pong = r.ping()
    except Exception as e:
        return {"status": "error", "error": str(e), "ts": now_iso()}
    modules = len(list((CYBRA/"modules").glob("module_*")))
    return {
        "status": "ok",
        "redis": "PONG" if pong else "DOWN",
        "modules": modules,
        "token": TOKEN_CYBRA,
        "commission_pct": COMMISSION_PCT,
        "ts": now_iso(),
    }

@app.get("/api/state/100", tags=["system"])
def state_100():
    res = call_module(266, "check")
    return {"rc": res["rc"], "output": res["stdout"], "ready": res["rc"] == 0}

# ═══════════════ AUTH ═══════════════
@app.post("/api/auth/register", tags=["auth"])
def register(body: RegisterIn):
    key = f"cybra:user:{body.phone}"
    if r.exists(key):
        raise HTTPException(400, "already registered")
    r.hset(key, mapping={"phone": body.phone, "role": body.role, "created": now_iso()})
    # TODO: send OTP via SMS. For dev: return fixed code
    dev_code = "1234"
    r.setex(f"cybra:otp:{body.phone}", 300, dev_code)
    return {"status": "registered", "dev_otp": dev_code, "note": "dev mode — use code=1234"}

@app.post("/api/auth/login", tags=["auth"])
def login(body: LoginIn):
    code = r.get(f"cybra:otp:{body.phone}")
    if not code:
        raise HTTPException(400, "no OTP — register first")
    if body.code != code:
        raise HTTPException(401, "bad code")
    r.delete(f"cybra:otp:{body.phone}")
    user = r.hgetall(f"cybra:user:{body.phone}")
    if not user:
        raise HTTPException(404, "user not found")
    token = make_jwt(body.phone, user.get("role", "rider"))
    return {"token": token, "role": user.get("role"), "phone": body.phone}

@app.get("/api/me", tags=["auth"])
def me(user: dict = Depends(current_user)):
    data = r.hgetall(f"cybra:user:{user['sub']}")
    return {"phone": user["sub"], "role": user.get("role"), "data": data}

# ═══════════════ RIDES ═══════════════
@app.post("/api/rides", tags=["rides"])
def create_ride(body: RideIn, user: dict = Depends(current_user)):
    rid = gen_id("R")
    price = body.price or round(body.km * 15, 2)
    data = {
        "id": rid, "rider": user["sub"], "driver": None,
        "pickup": body.pickup, "dropoff": body.dropoff,
        "km": body.km, "price": price, "status": "created",
        "created_at": now_iso(),
        "pickup_lat": body.pickup_lat, "pickup_lon": body.pickup_lon,
    }
    r.hset(f"cybra:taxi:ride:{rid}", mapping={k: str(v) for k, v in data.items()})
    r.rpush(f"cybra:taxi:rides:{user['sub']}", rid)
    r.rpush("cybra:taxi:rides:open", rid)
    ev = push_event("ride.created", {"ride_id": rid, "from": body.pickup, "to": body.dropoff}, "api")
    return {"ride": data, "event_id": ev}

@app.get("/api/rides", tags=["rides"])
def list_rides(user: dict = Depends(current_user), limit: int = 20):
    ids = r.lrange(f"cybra:taxi:rides:{user['sub']}", -limit, -1)
    return {"count": len(ids), "rides": [r.hgetall(f"cybra:taxi:ride:{i}") for i in ids]}

@app.get("/api/rides/open", tags=["rides"])
def open_rides(limit: int = 30):
    ids = r.lrange("cybra:taxi:rides:open", -limit, -1)
    return {"count": len(ids), "rides": [r.hgetall(f"cybra:taxi:ride:{i}") for i in ids]}

@app.get("/api/rides/{rid}", tags=["rides"])
def get_ride(rid: str):
    data = r.hgetall(f"cybra:taxi:ride:{rid}")
    if not data:
        raise HTTPException(404, "ride not found")
    return data

@app.post("/api/rides/{rid}/accept", tags=["rides"])
def accept_ride(rid: str, user: dict = Depends(require_role("driver", "both"))):
    key = f"cybra:taxi:ride:{rid}"
    if not r.exists(key): raise HTTPException(404)
    cur = r.hget(key, "status")
    if cur != "created": raise HTTPException(400, f"cannot accept from status={cur}")
    r.hset(key, mapping={"driver": user["sub"], "status": "accepted", "accepted_at": now_iso()})
    push_event("ride.accepted", {"ride_id": rid, "driver": user["sub"]}, "api")
    return {"status": "accepted", "ride_id": rid}

@app.post("/api/rides/{rid}/start", tags=["rides"])
def start_ride(rid: str, user: dict = Depends(require_role("driver", "both"))):
    key = f"cybra:taxi:ride:{rid}"
    if r.hget(key, "driver") != user["sub"]: raise HTTPException(403, "not your ride")
    r.hset(key, mapping={"status": "in_progress", "started_at": now_iso()})
    return {"status": "in_progress"}

@app.post("/api/rides/{rid}/complete", tags=["rides"])
def complete_ride(rid: str, user: dict = Depends(require_role("driver", "both"))):
    key = f"cybra:taxi:ride:{rid}"
    if r.hget(key, "driver") != user["sub"]: raise HTTPException(403)
    price = float(r.hget(key, "price") or 0)
    fee = round(price * COMMISSION_PCT / 100, 2)
    net = round(price - fee, 2)
    r.hset(key, mapping={"status": "completed", "completed_at": now_iso(),
                          "fee": str(fee), "net": str(net)})
    r.lrem("cybra:taxi:rides:open", 0, rid)
    r.hset(f"cybra:taxi:commission:data", rid,
           f"amount={price},fee={fee},net={net},token={TOKEN_CYBRA},status=pending")
    push_event("ride.completed", {"ride_id": rid, "price": price, "fee": fee}, "api")
    push_event("payment.commission", {"amount": price, "ride_id": rid}, "api")
    return {"status": "completed", "price": price, "fee": fee, "net": net}

@app.post("/api/rides/{rid}/cancel", tags=["rides"])
def cancel_ride(rid: str, user: dict = Depends(current_user)):
    key = f"cybra:taxi:ride:{rid}"
    cur = r.hget(key, "status")
    if cur in ("completed", "cancelled"): raise HTTPException(400, "cannot cancel")
    r.hset(key, mapping={"status": "cancelled", "cancelled_at": now_iso()})
    r.lrem("cybra:taxi:rides:open", 0, rid)
    push_event("ride.cancelled", {"ride_id": rid}, "api")
    return {"status": "cancelled"}

# ═══════════════ MAP ═══════════════
@app.get("/api/map/markers", tags=["map"])
def map_markers():
    raw = r.hgetall("cybra:taxi:map:markers")
    out = []
    for k, v in raw.items():
        parts = v.split(",")
        if len(parts) >= 2:
            try: out.append({"id": k, "lat": float(parts[0]), "lon": float(parts[1]),
                             "note": parts[2] if len(parts) > 2 else ""})
            except: pass
    return {"count": len(out), "markers": out}

@app.post("/api/map/markers", tags=["map"])
def map_add(body: MarkerIn):
    r.hset("cybra:taxi:map:markers", body.id, f"{body.lat},{body.lon},{body.note},{now_iso()}")
    push_event("map.marker_added", body.dict(), "api")
    return {"status": "ok", "id": body.id}

@app.get("/api/map/near", tags=["map"])
def map_near(lat: float = Query(...), lon: float = Query(...), km: float = 5.0):
    raw = r.hgetall("cybra:taxi:map:markers")
    out = []
    for k, v in raw.items():
        parts = v.split(",")
        if len(parts) < 2: continue
        try:
            mlat, mlon = float(parts[0]), float(parts[1])
            dlat = abs(mlat - lat) * 111
            dlon = abs(mlon - lon) * 111 * 0.65
            dist = round((dlat**2 + dlon**2) ** 0.5, 2)
            if dist <= km:
                out.append({"id": k, "lat": mlat, "lon": mlon, "distance_km": dist})
        except: pass
    out.sort(key=lambda x: x["distance_km"])
    return {"count": len(out), "within_km": km, "markers": out}

@app.post("/api/map/zones", tags=["map"])
def map_zone(body: ZoneIn):
    r.hset("cybra:taxi:map:zones", body.id,
           f"{body.lat},{body.lon},{body.radius},{body.reason}")
    push_event("map.zone_added", body.dict(), "api")
    return {"status": "ok", "id": body.id}

@app.get("/api/map/zones", tags=["map"])
def map_zones_list():
    return {"zones": r.hgetall("cybra:taxi:map:zones")}

# ═══════════════ WALLET ═══════════════
@app.post("/api/wallet/connect", tags=["wallet"])
def wallet_connect(body: WalletIn, user: dict = Depends(current_user)):
    r.hset("cybra:taxi:wallet:data", body.address, f"role={body.role},at={now_iso()}")
    push_event("wallet.connected", body.dict(), "api")
    return {"status": "connected", "address": body.address, "role": body.role}

@app.get("/api/wallet", tags=["wallet"])
def wallet_list():
    return {"wallets": r.hgetall("cybra:taxi:wallet:data")}

@app.delete("/api/wallet/{addr}", tags=["wallet"])
def wallet_remove(addr: str):
    r.hdel("cybra:taxi:wallet:data", addr)
    return {"status": "removed"}

@app.get("/api/wallet/{addr}/balance", tags=["wallet"])
def wallet_balance(addr: str):
    return {"address": addr,
            "cybra": r.get(f"cybra:wallet:{addr}:cybra") or "0",
            "bnb": r.get(f"cybra:wallet:{addr}:bnb") or "0",
            "note": "on-chain balance needs RPC"}

# ═══════════════ PRICE ═══════════════
@app.post("/api/price/offer", tags=["price"])
def price_offer(body: PriceOfferIn, user: dict = Depends(current_user)):
    r.hset(f"cybra:taxi:price:negotiate:{body.ride_id}",
           "client_offer", str(body.amount))
    push_event("price.offered", body.dict(), "api")
    return {"status": "offered"}

@app.post("/api/price/counter", tags=["price"])
def price_counter(body: PriceOfferIn, user: dict = Depends(current_user)):
    r.hset(f"cybra:taxi:price:negotiate:{body.ride_id}",
           "driver_ask", str(body.amount))
    push_event("price.countered", body.dict(), "api")
    return {"status": "countered"}

@app.post("/api/price/accept", tags=["price"])
def price_accept(body: PriceAcceptIn, user: dict = Depends(current_user)):
    r.hset(f"cybra:taxi:price:negotiate:{body.ride_id}",
           "accepted_by", body.who)
    push_event("price.accepted", body.dict(), "api")
    return {"status": "accepted"}

@app.post("/api/price/per_km", tags=["price"])
def price_per_km(body: PerKmIn):
    r.hset("cybra:taxi:price:perkm", body.who, str(body.price))
    push_event("price.per_km", body.dict(), "api")
    return {"status": "ok", "who": body.who, "price": body.price}

@app.get("/api/price/suggest", tags=["price"])
def price_suggest(km: float = 5.0):
    base = round(km * 15, 2)
    return {"km": km, "low": round(base*0.8, 2), "base": base, "high": round(base*1.2, 2)}

@app.get("/api/price/negotiate/{rid}", tags=["price"])
def price_negotiate(rid: str):
    return r.hgetall(f"cybra:taxi:price:negotiate:{rid}")

# ═══════════════ AI MATCH ═══════════════
@app.post("/api/ai/interests", tags=["ai"])
def ai_interests(body: InterestsIn):
    key = f"cybra:taxi:interests:{body.who}"
    r.delete(key)
    for tag in body.tags:
        r.sadd(key, tag)
    return {"who": body.who, "tags": body.tags}

@app.post("/api/ai/match", tags=["ai"])
def ai_match(body: MatchIn):
    rider_tags = r.smembers(f"cybra:taxi:interests:{body.rider_id}")
    best = None; best_score = 0
    for k in r.keys("cybra:taxi:interests:*"):
        driver = k.split(":")[-1]
        if driver == body.rider_id: continue
        d_tags = r.smembers(k)
        score = len(rider_tags & d_tags)
        if score > best_score:
            best_score = score; best = driver
    return {"rider": body.rider_id, "rider_tags": list(rider_tags),
            "best_driver": best, "shared_tags": best_score}

# ═══════════════ PAYMENT ═══════════════
@app.post("/api/payment/commission", tags=["payment"])
def payment_commission(body: CommissionIn):
    fee = round(body.amount * COMMISSION_PCT / 100, 2)
    net = round(body.amount - fee, 2)
    rid = gen_id("COM")
    r.hset("cybra:taxi:commission:data", rid,
           f"amount={body.amount},fee={fee},net={net},token={TOKEN_CYBRA},status=pending")
    push_event("payment.commission", body.dict(), "api")
    return {"ref": rid, "amount": body.amount, "fee": fee, "net": net,
            "token": TOKEN_CYBRA, "commission_pct": COMMISSION_PCT,
            "note": "on-chain transfer needs wallet signing"}

@app.post("/api/payment/instant", tags=["payment"])
def payment_instant(body: InstantIn):
    rid = gen_id("PAY")
    r.hset("cybra:taxi:payment:data", rid,
           f"from={body.from_addr},to={body.to_addr},amount={body.amount},status=queued")
    push_event("payment.instant", body.dict(by_alias=True), "api")
    return {"ref": rid, "status": "queued",
            "note": "bank card→card needs PSP (LiqPay/Fondy)"}

@app.post("/api/payment/contract", tags=["payment"])
def payment_contract(body: ContractIn):
    res = call_module(248, "contract", str(body.amount), body.driver, body.rider, timeout=30)
    return {"rc": res["rc"], "stdout": res["stdout"], "note": "sign via MetaMask"}

# ═══════════════ RATING ═══════════════
@app.post("/api/rating", tags=["rating"])
def rating_add(body: RatingIn, user: dict = Depends(current_user)):
    rid = gen_id("R")
    r.hset("cybra:taxi:rating:data", rid,
           f"{body.who}|score={body.score}|{body.comment}|{now_iso()}")
    push_event("rating.added", body.dict(), "api")
    return {"status": "ok", "ref": rid, "note": "rating does NOT affect dispatch"}

@app.get("/api/rating", tags=["rating"])
def rating_view(who: Optional[str] = None):
    all_r = r.hgetall("cybra:taxi:rating:data")
    if who:
        all_r = {k: v for k, v in all_r.items() if v.startswith(f"{who}|")}
    return {"count": len(all_r), "ratings": all_r}

# ═══════════════ I18N ═══════════════
@app.get("/api/i18n/{lang}", tags=["i18n"])
def i18n_get(lang: str):
    f = CYBRA/"state/taxi/i18n"/f"{lang}.json"
    if not f.exists(): raise HTTPException(404, f"lang {lang} not found")
    return json.loads(f.read_text())

@app.post("/api/i18n/lang", tags=["i18n"])
def i18n_set(body: I18nIn, user: dict = Depends(current_user)):
    r.set(f"cybra:taxi:i18n:lang:{user['sub']}", body.lang)
    return {"status": "ok", "lang": body.lang}

# ═══════════════ EVENTS (proxy) ═══════════════
@app.post("/api/taxi/events", tags=["events"])
def post_event(body: EventIn):
    ev = push_event(body.type, body.data, body.src)
    return {"status": "queued", "event_id": ev}

@app.get("/api/taxi/events/stats", tags=["events"])
def events_stats():
    return r.hgetall("cybra:taxi:events:stats")

# ═══════════════ ENTRYPOINT ═══════════════
if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    print(f"═══ CYBRA API ═══")
    print(f"  port:    {port}")
    print(f"  swagger: http://0.0.0.0:{port}/docs")
    print(f"  token:   {TOKEN_CYBRA}")
    print(f"  commission: {COMMISSION_PCT}%")
    print(f"  redis:   {REDIS_HOST}:{REDIS_PORT}")
    print(f"  modules: {CYBRA/'modules'}")
    print(f"  jwt_secret: {'[saved]' if os.environ.get('CYBRA_JWT_SECRET') else '[RANDOM — set env to persist]'}")
    uvicorn.run("server:app", host="0.0.0.0", port=port, reload=False)
