// Integration test against the real Ep128web core. ROMs and core are external.
const fs=require('fs'),path=require('path');
const root=__dirname;
const moduleFile=process.env.EP128WEB_MODULE||path.resolve(root,'../tooling/ep128web-dist/ep128emu.js');
const romDir=process.env.TVC_ROM_DIR||path.resolve(root,'../tooling/jtvcemu/rom');
const factory=require(moduleFile);
const symbols=Object.fromEntries([...fs.readFileSync(path.join(root,'build/native.sym'),'utf8').matchAll(/(\S+): EQU 0x([\da-f]+)/ig)].map(m=>[m[1],parseInt(m[2],16)]));
(async()=>{
 const M=await factory(),c=(n,r,a)=>M.cwrap(n,r,a);
 const load=c('ep_load_rom','number',['number','string','number']);
 const regs=c('ep_dbg_regs','string',[]),io=c('ep_dbg_io_regs','string',[]);
 const info=c('ep_dbg_info','string',[]);
 M.FS.mkdir('/roms');M.FS.writeFile('/roms/sys',Buffer.concat(['TVC12_D4.BIN','TVC12_D3.BIN'].map(n=>fs.readFileSync(path.join(romDir,n)))));
 M.FS.writeFile('/roms/ext',fs.readFileSync(path.join(romDir,'TVC12_D7.BIN')));
 M._ep_init(48000);M._ep_set_machine_type(1);M._ep_reset_memory(128);load(0,'/roms/sys',0);load(2,'/roms/ext',0);M._ep_reset(1);
 let audioProbe=false,audioMin=Infinity,audioMax=-Infinity,audioCount=0;
 const run=ms=>{for(let t=0;t<ms;t+=20){if(M._ep_run(20000))throw Error('Emulator error');if(audioProbe){const ptr=M._ep_audio_buffer()>>>2,n=M._ep_audio_frames()*2;for(let j=0;j<n;j++){const v=M.HEAPF32[ptr+j];audioMin=Math.min(audioMin,v);audioMax=Math.max(audioMax,v);}audioCount+=n;}M._ep_audio_clear();}};
 const state=()=>{const old=regs().split(' ').map(Number);M._ep_dbg_out(2,0xb0);const s=[0x5b04,0xfde1,0xfde2].map(a=>M._ep_read_memory(a));if(old[19]>=0xfc)M._ep_dbg_out(2,0x90);return s;};
 const dump=tag=>{const p=M._ep_frame_buffer()>>>2,w=M._ep_frame_width(),h=M._ep_frame_height(),b=Buffer.alloc(w*h*3);for(let i=0;i<w*h;i++){const v=M.HEAPU32[p+i];b[i*3]=v&255;b[i*3+1]=v>>>8&255;b[i*3+2]=v>>>16&255;}fs.writeFileSync(path.join(root,'build/'+tag+'.ppm'),Buffer.concat([Buffer.from(`P6\n${w} ${h}\n255\n`),b]));};
 run(12000);M._ep_dbg_out(2,0xb0);const b=fs.readFileSync(path.join(root,'Nodes_Yesod_TVC_native_v09.cas')).subarray(144);
 for(let i=0;i<b.length;i++)M._ep_write_memory(0x19ef+i,b[i]);
 M._ep_dbg_set_reg(0,parseInt(b.subarray(9,13).toString(),10));M._ep_dbg_set_reg(15,0);M._ep_dbg_set_reg(16,0);
 audioProbe=true;run(5000);audioProbe=false;console.log('MENU_AUDIO',audioCount,audioMin,audioMax);if(!(audioMax-audioMin>0.001))throw Error('Menu audio is silent');dump('menu-v09');console.log('sync_available',M._ep_read_memory(symbols.sync_available));
 M._ep_set_key(0x19,1);run(100);M._ep_set_key(0x19,0);run(2500);console.log('start',state());
 M._ep_dbg_set_bp(symbols['frame.done'],1);
 const samples=[];M._ep_set_key(0x4c,1);
 for(let n=0;n<24;n++){M._ep_dbg_continue();run(1000);const r=regs().split(' ').map(Number);if(r[0]!==symbols['frame.done'])throw Error('Frame breakpoint was not reached: '+info());const s={line:M._ep_dbg_video_line(),frame:M._ep_dbg_video_frame(),display:M._ep_read_memory(symbols.display_page),sync:M._ep_read_memory(symbols.sync_available),state:state(),io:io()};samples.push(s);if(n%6===0)dump('moving-'+n);}
 M._ep_dbg_set_bp(symbols['frame.done'],0);M._ep_dbg_continue();M._ep_set_key(0x4c,0);run(100);console.log('after P',state());
 let min=255,max=0;M._ep_set_key(0x46,1);for(let n=0;n<50;n++){run(20);let y=state()[2];min=Math.min(min,y);max=Math.max(max,y);}M._ep_set_key(0x46,0);run(100);dump('game-v09');
 console.log('jump_y',min,max,'end',state());console.log('flip_samples',JSON.stringify(samples.map(({line,display,sync,state})=>({line,display,sync,state}))));
 fs.writeFileSync(path.join(root,'build/vblank-samples.json'),JSON.stringify(samples,null,2));
 if(samples.some(s=>s.sync!==1))throw Error('Frame synchronisation was not active');
 if(samples.some((s,i)=>i&&s.display===samples[i-1].display))throw Error('Buffers did not alternate');
 M._ep_dbg_out(2,0xb0);M._ep_write_memory(0x9ca5,180);audioMin=Infinity;audioMax=-Infinity;audioCount=0;audioProbe=true;run(150);audioProbe=false;console.log('EFFECT_AUDIO',audioCount,audioMin,audioMax);if(!(audioMax-audioMin>0.001))throw Error('Effect audio is silent');
 console.log('REAL_CORE_PASS');
})();
