#!/usr/bin/env node
'use strict';
const fs=require('fs'),path=require('path'),crypto=require('crypto');const L=require('./lib');
const b=L.readJSON(path.join(L.STATE,'binding.json')),d=L.readJSON(path.join(L.STATE,'deployment.json'));if(!b)throw new Error('Binding not found');const link={schema_version:1,node_id:b.node_id,repository:b.full_name,installation_id:b.installation_id,branch:d?.branch||'cybra-node',commit:d?.commit||null,update_channel:'stable',control_mode:'repository-mediated',master_shell_access:false,telemetry:'local-only',link_secret_sha256:crypto.createHash('sha256').update(crypto.randomBytes(32)).digest('hex'),created_at:new Date().toISOString()};L.atomicJSON(path.join(L.STATE,'node-link.json'),link);console.log(JSON.stringify(link,null,2));
