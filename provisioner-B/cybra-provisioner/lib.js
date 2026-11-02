#!/usr/bin/env node
'use strict';
const fs=require('fs'),path=require('path'),crypto=require('crypto'),https=require('https');
const ROOT=process.env.CYBRA_PROVISIONER_ROOT||path.join(process.env.HOME||'.','CYBRA','provisioner');
const STATE=path.join(ROOT,'state'); fs.mkdirSync(STATE,{recursive:true,mode:0o700});
function readJSON(f,d=null){try{return JSON.parse(fs.readFileSync(f,'utf8'))}catch{return d}}
function atomicJSON(f,v){fs.mkdirSync(path.dirname(f),{recursive:true,mode:0o700});const t=f+'.tmp.'+process.pid;fs.writeFileSync(t,JSON.stringify(v,null,2)+'\n',{mode:0o600});fs.renameSync(t,f)}
function req(method,url,token,body){return new Promise((resolve,reject)=>{const u=new URL(url),data=body?JSON.stringify(body):null;const q=https.request({hostname:u.hostname,path:u.pathname+u.search,method,headers:{Accept:'application/vnd.github+json','X-GitHub-Api-Version':'2022-11-28','User-Agent':'cybra-provisioner/1.0',...(token?{Authorization:'Bearer '+token}:{}),...(data?{'Content-Type':'application/json','Content-Length':Buffer.byteLength(data)}:{})}},r=>{let out='';r.on('data',c=>out+=c);r.on('end',()=>{let parsed=out;try{parsed=out?JSON.parse(out):{}}catch{};if(r.statusCode>=200&&r.statusCode<300)resolve(parsed);else reject(new Error(`GitHub ${r.statusCode}: ${typeof parsed==='string'?parsed:JSON.stringify(parsed)}`))})});q.on('error',reject);if(data)q.write(data);q.end()})}
function b64url(v){return Buffer.from(v).toString('base64url')}
function appJWT(appId,keyFile){const now=Math.floor(Date.now()/1000),head=b64url(JSON.stringify({alg:'RS256',typ:'JWT'})),pay=b64url(JSON.stringify({iat:now-60,exp:now+540,iss:String(appId)})),data=head+'.'+pay,key=fs.readFileSync(keyFile);return data+'.'+crypto.sign('RSA-SHA256',Buffer.from(data),key).toString('base64url')}
async function installationToken(appId,keyFile,installationId){const jwt=appJWT(appId,keyFile);const r=await req('POST',`https://api.github.com/app/installations/${installationId}/access_tokens`,jwt,{});return r.token}
function nodeId(owner,repo,installation){return 'cybra-'+crypto.createHash('sha256').update(`${owner}/${repo}:${installation}`).digest('hex').slice(0,12)}
function sh(cmd,args,opts={}){const r=require('child_process').spawnSync(cmd,args,{encoding:'utf8',stdio:opts.inherit?'inherit':'pipe',env:process.env,cwd:opts.cwd});if(r.status!==0)throw new Error(`${cmd} failed: ${r.stderr||r.status}`);return r.stdout||''}
module.exports={ROOT,STATE,readJSON,atomicJSON,req,installationToken,nodeId,sh};
