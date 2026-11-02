#!/usr/bin/env node
'use strict';
const fs=require('fs'),path=require('path'),crypto=require('crypto');const L=require('./lib');
const b=L.readJSON(path.join(L.STATE,'binding.json'));if(!b){console.error('[ERROR] Run 01-github-auth.js first');process.exit(1)}
const out=path.join(L.ROOT,'work',b.node_id);fs.rmSync(out,{recursive:true,force:true});for(const d of ['config','bootstrap','core','cli','state'])fs.mkdirSync(path.join(out,d),{recursive:true});
const config={schema_version:1,node_id:b.node_id,owner:b.owner,repository:b.repository,full_name:b.full_name,installation_id:b.installation_id,update_channel:'stable',master_access:false,telemetry:'local-only',created_at:new Date().toISOString()};
L.atomicJSON(path.join(out,'config','node.json'),config);fs.writeFileSync(path.join(out,'.env.example'),'CYBRA_NODE_ID='+b.node_id+'\nCYBRA_CHANNEL=stable\nCYBRA_MASTER_ACCESS=false\n',{mode:0o600});
fs.writeFileSync(path.join(out,'README.md'),`# CYBRA Client Node\n\nNode: ${b.node_id}\nRepository: ${b.full_name}\n\nRun: \`bash bootstrap/05-node-bootstrap.sh\`\n`);
L.atomicJSON(path.join(L.STATE,'provision.json'),{node_id:b.node_id,workdir:out,created_at:new Date().toISOString()});console.log(out);
