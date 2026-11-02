'use strict';
const path=require('path'),root=path.join(process.env.HOME,'CYBRA');
module.exports={apps:[{name:'cybra-core',script:path.join(root,'core','autonomous-core.js'),cwd:root,interpreter:'node',autorestart:true,watch:false,min_uptime:'10s',max_restarts:10,restart_delay:3000,exp_backoff_restart_delay:1000,max_memory_restart:'150M',time:true,env:{NODE_ENV:'production'}}]};
