#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

ROOT="$HOME/CYBRA"
CORE="$ROOT/core"
STATE="$ROOT/state"
CLI="$ROOT/cli"
OPENID="$ROOT/openid"
ENV="$OPENID/.env"
BACKUPS="$ROOT/backups"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$BACKUPS/pre-v3-$STAMP"

info(){ printf '[INFO] %s\n' "$*"; }
ok(){ printf '[OK] %s\n' "$*"; }
die(){ printf '[ERROR] %s\n' "$*" >&2; exit 1; }

command -v node >/dev/null || die 'Node.js missing: pkg install nodejs'
command -v npm >/dev/null || die 'npm missing'
command -v curl >/dev/null || die 'curl missing: pkg install curl'
command -v pm2 >/dev/null || npm install -g pm2

mkdir -p "$CORE" "$STATE" "$CLI" "$OPENID" "$BACKUPS" "$ROOT/snapshots" "$ROOT/incidents"
mkdir -p "$BACKUP"
touch "$ENV"
chmod 600 "$ENV"
cp -a "$ENV" "$BACKUP/openid.env" 2>/dev/null || true
pm2 jlist > "$BACKUP/pm2-before.json" 2>/dev/null || true

set_default(){ grep -q "^$1=" "$ENV" 2>/dev/null || printf '%s=%s\n' "$1" "$2" >> "$ENV"; }
set_default CYBRA_CORE_INTERVAL 15
set_default CYBRA_HEALTH_URL http://127.0.0.1:8787/health
set_default CYBRA_TARGET_HEALTH 100
set_default CYBRA_AI_TOLERANCE 3
set_default CYBRA_AI_ENABLED true
set_default CYBRA_AI_AUTO_APPLY true
set_default CYBRA_AI_COOLDOWN 300
set_default CYBRA_RESTART_LIMIT 5
set_default CYBRA_RESTART_WINDOW 600
set_default CYBRA_RESTART_COOLDOWN 900
set_default CYBRA_REQUIRED_PM2 cybra-monolith,cybra-openid
set_default CYBRA_RAM_YELLOW_PCT 20
set_default CYBRA_RAM_RED_PCT 10
set_default CYBRA_DISK_YELLOW_MB 1024
set_default CYBRA_DISK_RED_MB 256

cat > "$CORE/autonomous-core.js" <<'NODE'
#!/usr/bin/env node
'use strict';
const fs=require('fs'), os=require('os'), path=require('path'), http=require('http'), https=require('https');
const {spawnSync}=require('child_process');
const H=process.env.HOME,R=path.join(H,'CYBRA'),S=path.join(R,'state'),E=path.join(R,'openid','.env');
function env(){if(!fs.existsSync(E))return;for(const l0 of fs.readFileSync(E,'utf8').split(/\r?\n/)){const l=l0.trim();if(!l||l.startsWith('#')||!l.includes('='))continue;const i=l.indexOf('='),k=l.slice(0,i).trim();let v=l.slice(i+1).trim();if((v[0]==='"'&&v.at(-1)==='"')||(v[0]==="'"&&v.at(-1)==="'"))v=v.slice(1,-1);if(process.env[k]===undefined)process.env[k]=v;}} env();
const n=(k,d)=>{const x=parseInt(process.env[k]||'',10);return Number.isFinite(x)?x:d};
const cfg={interval:n('CYBRA_CORE_INTERVAL',15),url:process.env.CYBRA_HEALTH_URL||'http://127.0.0.1:8787/health',target:n('CYBRA_TARGET_HEALTH',100),tol:n('CYBRA_AI_TOLERANCE',3),required:(process.env.CYBRA_REQUIRED_PM2||'cybra-monolith,cybra-openid').split(',').map(x=>x.trim()),ramY:n('CYBRA_RAM_YELLOW_PCT',20),ramR:n('CYBRA_RAM_RED_PCT',10),diskY:n('CYBRA_DISK_YELLOW_MB',1024),diskR:n('CYBRA_DISK_RED_MB',256)};
const run=(b,a=[])=>{const r=spawnSync(b,a,{encoding:'utf8',env:process.env,maxBuffer:16*1024*1024});return{ok:r.status===0,out:r.stdout||'',err:r.stderr||''}};
const atomic=(f,o)=>{fs.mkdirSync(path.dirname(f),{recursive:true});const t=f+'.tmp.'+process.pid;fs.writeFileSync(t,JSON.stringify(o,null,2)+'\n',{mode:0o600});fs.renameSync(t,f)};
const probe=()=>new Promise(res=>{let u;try{u=new URL(cfg.url)}catch(e){return res({ok:false,status:0,reason:e.message})}const tr=u.protocol==='https:'?https:http,st=Date.now();const q=tr.get(u,{timeout:5000},r=>{r.resume();const ok=r.statusCode>=200&&r.statusCode<300;res({ok,status:r.statusCode||0,latency_ms:Date.now()-st,reason:ok?'Health endpoint passed':'HTTP '+r.statusCode})});q.on('timeout',()=>q.destroy(new Error('timeout')));q.on('error',e=>res({ok:false,status:0,latency_ms:Date.now()-st,reason:e.message}))});
async function cycle(){let list=[];const p=run('pm2',['jlist']);if(p.ok)try{list=JSON.parse(p.out).map(x=>({name:x.name||x.pm2_env?.name,status:x.pm2_env?.status||'unknown',pid:x.pid||0,cpu_pct:x.monit?.cpu||0,memory_mb:Math.round((x.monit?.memory||0)/104857.6)/10,restarts:x.pm2_env?.restart_time||0}))}catch{}const hp=await probe();const total=os.totalmem(),free=os.freemem(),ram=Math.round((free/total)*1000)/10;let disk=0;const d=run('df',['-Pk',R]);if(d.ok){const row=d.out.trim().split(/\r?\n/).at(-1).trim().split(/\s+/);disk=Math.round((Number(row[3])||0)/102.4)/10}let serviceScore=0;for(const name of cfg.required){if(list.find(x=>x.name===name&&x.status==='online'))serviceScore+=30/Math.max(1,cfg.required.length)}let resource=15;if(ram<=cfg.ramR)resource-=8;else if(ram<=cfg.ramY)resource-=4;if(disk<=cfg.diskR)resource-=7;else if(disk<=cfg.diskY)resource-=3;resource=Math.max(0,resource);const api=hp.ok?25:0,stability=15,selfHeal=10,queue=5;let pct=Math.round((serviceScore+api+resource+stability+selfHeal+queue)*10)/10;let level=pct===100?'optimal':pct>=97?'healthy':pct>=90?'degraded':pct>=70?'recovery':'critical';let color=pct>=97?'green':pct>=90?'yellow':pct>=70?'red':'black';const items={};for(const name of cfg.required){const x=list.find(y=>y.name===name);items['pm2:'+name]=x?.status==='online'?{color:'green',reason:'Process online'}:x?{color:'red',reason:'PM2 status is '+x.status}:{color:'black',reason:'Required process not found'}}items.openid_health={color:hp.ok?'green':'red',reason:hp.reason};items.ram={color:ram<=cfg.ramR?'red':ram<=cfg.ramY?'yellow':'green',reason:ram+'% RAM available'};items.disk={color:disk<=cfg.diskR?'red':disk<=cfg.diskY?'yellow':'green',reason:disk+' MB disk available'};const colors={green:0,yellow:0,red:0,black:0};Object.values(items).forEach(x=>colors[x.color]++);const aiFile=path.join(S,'ai-learning.json');let ai={enabled:String(process.env.CYBRA_AI_ENABLED||'true')==='true',mode:pct>=cfg.target-cfg.tol?'learning':'observing',target:cfg.target,tolerance:cfg.tol,total_cycles:0,total_actions:0,rewards:0,penalties:0,neutral:0,last_action:'none',last_decision:pct>=cfg.target-cfg.tol?'healthy-zone':'diagnose',last_delta:0};try{ai={...ai,...JSON.parse(fs.readFileSync(aiFile,'utf8'))}}catch{}ai.total_cycles=(ai.total_cycles||0)+1;ai.mode=pct>=cfg.target-cfg.tol?'learning':'observing';ai.last_decision=pct>=cfg.target-cfg.tol?'healthy-zone':'diagnose';atomic(aiFile,ai);const manifest={schema_version:3,generated_at:new Date().toISOString(),overall:{percent:pct,color,level,sections:{services:serviceScore,api,resources:resource,stability,self_heal:selfHeal,queue}},colors,resources:{ram_avail_pct:ram,disk_mb:disk,pm2_memory_mb:list.reduce((a,x)=>a+x.memory_mb,0),pm2_cpu_pct:list.reduce((a,x)=>a+x.cpu_pct,0)},services:list,health:{openid:hp},items,ai,survival:{active:pct<70,mode:pct<70?'survival':'normal'},circuits:{open:0,names:[]},self_heal:{status:'active'}};atomic(path.join(S,'manifest.json'),manifest);const online=cfg.required.every(name=>list.some(x=>x.name===name&&x.status==='online'));const stage=online&&hp.ok&&pct>=97?5:online?4:list.length?2:1;atomic(path.join(S,'stage.json'),{stage,name:stage===5?'ready':stage===4?'services-online':stage===2?'process-manager-online':'bootstrapping',gates_pass:stage===5,updated_at:new Date().toISOString()});console.log(new Date().toISOString(),'health='+pct+'%/'+level,'stage='+stage,'ai='+ai.mode)}
cycle();setInterval(cycle,Math.max(5,cfg.interval)*1000);
NODE
chmod +x "$CORE/autonomous-core.js"
node --check "$CORE/autonomous-core.js"

cat > "$CLI/cybra.js" <<'NODE'
#!/usr/bin/env node
'use strict';
const fs=require('fs'),path=require('path'),readline=require('readline');const{spawnSync}=require('child_process');
const R=path.join(process.env.HOME,'CYBRA'),M=path.join(R,'state','manifest.json'),S=path.join(R,'state','stage.json');
const j=(f,d=null)=>{try{return JSON.parse(fs.readFileSync(f,'utf8'))}catch{return d}};const run=(b,a=[])=>spawnSync(b,a,{stdio:'inherit',env:process.env});
function status(){const m=j(M);if(!m){console.log('CYBRA manifest not ready');return}const s=j(S,{});console.log('\nCYBRA OPERATIONS CENTER\n');console.log(`Health:     ${m.overall.percent}% ${String(m.overall.level).toUpperCase()}`);console.log(`Stage:      ${s.stage||0} ${s.name||'initializing'}`);console.log(`AI:         ${String(m.ai?.mode||'unknown').toUpperCase()}`);console.log(`Survival:   ${m.survival?.active?'ON':'OFF'}`);console.log(`Circuits:   ${m.circuits?.open||0} open\n`)}
function components(){const m=j(M);if(!m)return console.log('Manifest unavailable');for(const [k,v] of Object.entries(m.items||{}))console.log(`${v.color.toUpperCase().padEnd(7)} ${k.padEnd(24)} ${v.reason}`)}
function ai(){const m=j(M);console.log(JSON.stringify(m?.ai||{},null,2))}
async function menu(){const rl=readline.createInterface({input:process.stdin,output:process.stdout});try{while(true){console.clear();status();console.log('1. Dashboard\n2. System Controls\n3. Component Status\n4. System Parameters\n5. AI Self-Evolution\n6. PM2 Status\n7. Diagnostics\n0. Exit\n');const c=await new Promise(r=>rl.question('Select option: ',x=>r(x.trim())));if(c==='0')return;if(c==='1')status();else if(c==='2'){console.log('1. Restart cybra-monolith\n2. Restart cybra-openid\n3. Restart cybra-core');const x=await new Promise(r=>rl.question('Select action: ',y=>r(y.trim())));const n={'1':'cybra-monolith','2':'cybra-openid','3':'cybra-core'}[x];if(n)run('pm2',['restart',n,'--update-env'])}else if(c==='3')components();else if(c==='4')console.log(fs.readFileSync(path.join(R,'openid','.env'),'utf8'));else if(c==='5')ai();else if(c==='6')run('pm2',['status']);else if(c==='7'){status();components();run('pm2',['status'])}await new Promise(r=>rl.question('\nPress ENTER...',()=>r()))}}finally{rl.close()}}
const a=process.argv.slice(2),c=a[0];if(!c){if(process.stdin.isTTY)menu();else status()}else if(c==='-p'||c==='--pct')console.log(j(M)?.overall?.percent??'unknown');else if(c==='-c'||c==='--color')console.log(j(M)?.overall?.color??'unknown');else if(c==='-s'||c==='--stage'){const s=j(S,{});console.log(`stage=${s.stage??'?'} ${s.name||'unknown'} gates=${s.gates_pass??false}`)}else if(c==='-r'||c==='--red'||c==='problems'){const m=j(M,{});for(const[k,v]of Object.entries(m.items||{}))if(v.color==='red'||v.color==='black')console.log(`${v.color}\t${k}\t${v.reason}`)}else if(c==='-j'||c==='--json')console.log(JSON.stringify(j(M,{}),null,2));else if(c==='status'||c==='dashboard')status();else if(c==='components')components();else if(c==='ai')ai();else if(c==='pm2')run('pm2',['status']);else if(c==='restart'&&a[1])run('pm2',['restart',a[1],'--update-env']);else if(c==='logs'&&a[1])run('pm2',['logs',a[1],'--lines','100']);else console.log('Usage: @cybra [status|components|ai|pm2|restart SERVICE|logs SERVICE|-p|-c|-s|-r|-j]');
NODE
chmod +x "$CLI/cybra.js"
node --check "$CLI/cybra.js"

cat > "$CLI/package.json" <<'JSON'
{"name":"cybra-node-cli","version":"3.0.0","private":true,"bin":{"@cybra":"./cybra.js"},"engines":{"node":">=18"}}
JSON

cat > "$ROOT/ecosystem.v3.config.js" <<'NODE'
'use strict';
const path=require('path'),root=path.join(process.env.HOME,'CYBRA');
module.exports={apps:[{name:'cybra-core',script:path.join(root,'core','autonomous-core.js'),cwd:root,interpreter:'node',autorestart:true,watch:false,min_uptime:'10s',max_restarts:10,restart_delay:3000,exp_backoff_restart_delay:1000,max_memory_restart:'150M',time:true,env:{NODE_ENV:'production'}}]};
NODE
node --check "$ROOT/ecosystem.v3.config.js"

info 'Registering @cybra'
rm -f "$PREFIX/bin/@cybra"
cd "$CLI"
npm link --force >/dev/null
hash -r

info 'Starting cybra-core'
pm2 delete cybra-core >/dev/null 2>&1 || true
pm2 start "$ROOT/ecosystem.v3.config.js" --only cybra-core --update-env
pm2 save

info 'Waiting for manifest'
for i in $(seq 1 20); do
  [ -s "$STATE/manifest.json" ] && [ -s "$STATE/stage.json" ] && break
  sleep 2
done
[ -s "$STATE/manifest.json" ] || die 'Manifest was not generated'
node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$STATE/manifest.json"

ok 'CYBRA Autonomous Core v3 installed'
echo
pm2 status
echo
@cybra status
echo
printf 'Backup: %s\n' "$BACKUP"
printf 'Run: @cybra\n'
