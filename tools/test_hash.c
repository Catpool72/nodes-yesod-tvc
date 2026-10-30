#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "z80.h"
static uint8_t ram[65536],video[65536],paging=0xb0,row,bank,keys,display;
static int composing=0,watched_compose=0;static unsigned long visible_writes=0,flips=0,indexed_prefixes=0;
static uint8_t readmem(void*u,uint16_t a){return a>=0x8000&&a<0xc000&&!(paging&32)?video[bank*16384+a-0x8000]:ram[a];}
static void writemem(void*u,uint16_t a,uint8_t v){if(a>=0x8000&&a<0xc000&&!(paging&32)){if(composing&&bank==display&&a>=0x8600&&a<0xb000)visible_writes++;video[bank*16384+a-0x8000]=v;}else ram[a]=v;}
static uint8_t input(z80*z,uint8_t p){uint8_t v=255;if(p==0x58){if((keys&1)&&row==7)v&=~32;if((keys&2)&&row==8)v&=~32;if((keys&4)&&row==8)v&=~2;if((keys&8)&&row==8)v&=~64;}return v;}
static void output(z80*z,uint8_t p,uint8_t v){if(p==2)paging=v;if(p==3)row=v&15;if(p==12){bank=(v>>2)&3;int next=(v>>4)&3;if(next!=display)flips++;display=next;}}
static unsigned long comp_cyc=0;static void tracked_step(z80*z){unsigned long c0=z->cyc;if(composing){uint8_t op=readmem(NULL,z->pc);if(op==0xdd||op==0xfd)indexed_prefixes++;}z80_step(z);if(composing)comp_cyc+=z->cyc-c0;}
static int state_lo=0,state_hi=0;
/* The engine keeps incremental-composition state (per-page image signatures,
   pending external writes). A test that resets the video pages must reset it too. */
static void reset_state(void){if(state_hi>state_lo)memset(ram+state_lo,0,state_hi-state_lo);}
static int checks_print=0;static int miny=255,maxy=0,roomset[256];
static int check(void){uint8_t expected[12288];memcpy(expected,ram+0x2000,sizeof(expected));int cm[]={0,1,2,1,2,1,2,3};for(int ent=0;ent<16;ent++){int e=0xfc00+32*ent;if(!(ram[e]&1))continue;int ptr=ram[e+7]+256*ram[e+8];if(ptr<0xe403||ptr>=0xea00)continue;int meta=ptr-3,flip=!!(ram[e+30]&128),tag=ram[meta+3+3*flip],b=tag/4,a=ram[meta+4+3*flip]+256*ram[meta+5+3*flip],stride=ram[meta+9];if(tag!=255&&(b<1||b>3||a<0x8000||a+stride*ram[e+4]>0xc000))return 999;int xx=ram[e+1]-((ram[e]&128)?256:0),yy=ram[e+2];if(yy>=192)yy-=256;int w=ram[e+3],h=ram[e+4],ink=((ram[e+5]>>4)&1)|((ram[e+5]&1)<<1);for(int y=0;y<h;y++)for(int x=0;x<w;x++){int vx=xx+x,vy=yy+y;if(vx<0||vx>=256||vy<0||vy>=168)continue;int q=tag==255?ram[a+y*stride+x/4]:video[b*16384+a-0x8000+y*stride+x/4],bit=3-x%4;if(!((q>>bit)&1))continue;int *unused=0;(void)unused;uint8_t*d=&expected[vy*64+vx/4];int sh=3-vx%4;*d=(*d&~(0x11<<sh))|((ink&1)<<(sh+4))|((ink>>1)<<sh);}}
 int bad=0;for(int i=0;i<12288;i++)if(expected[i]!=video[display*16384+1536+i]){if(checks_print==0&&bad<12)printf("pixel y=%d byte=%d expected=%02x actual=%02x bg=%02x\n",i/64,i%64,expected[i],video[display*16384+1536+i],ram[0x2000+i]);bad++;}checks_print++;return bad;}
static int run_units(z80*z,int compose,int erosion){watched_compose=compose;int fails=0,cases=0;for(int meta=0xe400;meta<0xe400+136*10;meta+=10){int ptr=meta+3,w=ram[meta],h=ram[meta+1];for(int flip=0;flip<2;flip++)for(int shift=0;shift<4;shift++)for(int edge=0;edge<5;edge++){memset(ram+0xfc00,0,512);memset(ram+0x5800,0,64);memset(ram+0x5900,0,64);reset_state();memcpy(video+1536,ram+0x2000,12288);memcpy(video+3*16384+1536,ram+0x2000,12288);int e=0xfc00;ram[e]=edge==1?129:1;ram[e+1]=edge==1?252+shift:(edge==2?252+shift:100+shift);ram[e+2]=edge==3?252:(edge==4?164:80);ram[e+3]=w;ram[e+4]=h;ram[e+5]=(uint8_t[]){0,0xf0,0x0f,0xff}[cases%4];ram[e+7]=ptr&255;ram[e+8]=ptr>>8;ram[e+30]=flip?128:0;paging=0xb0;bank=0;ram[0x7ee]=0xff;ram[0x7ef]=7;z->sp=0x7ee;z->pc=compose;unsigned long start=z->cyc;composing=1;while(z->pc!=0x7ff&&z->cyc-start<2000000)tracked_step(z);composing=0;int bad=check();cases++;if(bad||z->pc!=0x7ff){fails++;if(fails<6)printf("UNIT BAD ptr=%04x flip=%d shift=%d edge=%d bytes=%d pc=%04x\n",ptr,flip,shift,edge,bad,z->pc);}}}printf("sprite_cases=%d failures=%d\n",cases,fails);int erbad=0,ercases=0;memset(ram+0xfc00,0,512);for(int mask=0;mask<256;mask++)for(int side=0;side<2;side++){int addr=0x2000+(64+(mask%80))*64+side*62;uint8_t expected[12288];memcpy(expected,ram+0x2000,12288);memcpy(video+1536,expected,12288);memcpy(video+3*16384+1536,expected,12288);for(int y=0;y<2;y++){expected[addr-0x2000+y*64]&=(mask>>4)*17;expected[addr-0x2000+y*64+1]&=(mask&15)*17;}paging=0xb0;bank=0;ram[0x7ea]=ram[0x7eb]=ram[0x7ec]=ram[0x7ed]=0;ram[0x7ee]=0xff;ram[0x7ef]=7;z->sp=0x7ea;z->pc=erosion;z->a=mask;z->d=addr>>8;z->e=addr&255;unsigned long start=z->cyc;while(z->pc!=0x7ff&&z->cyc-start<100000)tracked_step(z);ercases++;if(z->pc!=0x7ff||memcmp(expected,ram+0x2000,12288)||(memcmp(expected,video+1536,12288)||memcmp(expected,video+3*16384+1536,12288)))erbad++;}printf("erosion_cases=%d failures=%d\n",ercases,erbad);printf("visible_sprite_writes=%lu flips=%lu indexed_prefixes=%lu\n",visible_writes,flips,indexed_prefixes);return (fails||erbad||visible_writes||indexed_prefixes)?1:0;}
static int run_bench(z80*z,int compose){
 watched_compose=compose;int syncaddr=strtol(getenv("SYNC_ADDR"),NULL,16);ram[syncaddr]=0;
 const int counts[]={1,4,8,16};int bad=0;
 for(int scene=0;scene<4;scene++){
  int n=counts[scene];memset(ram+0xfc00,0,512);memset(ram+0x5800,0,64);memset(ram+0x5900,0,64);reset_state();
  memcpy(video+1536,ram+0x2000,12288);memcpy(video+3*16384+1536,ram+0x2000,12288);
  int meta=0xe400+5*10;for(int i=0;i<n;i++){int e=0xfc00+32*i;ram[e]=1;ram[e+1]=1+(i%8)*28;ram[e+2]=32+(i/8)*48;ram[e+3]=ram[meta];ram[e+4]=ram[meta+1];ram[e+5]=(uint8_t[]){0xff,0xf0,0x0f,0xff}[i%4];ram[e+7]=(meta+3)&255;ram[e+8]=(meta+3)>>8;}
  unsigned long ticks=0,oldprefix=indexed_prefixes;
  for(int frame=0;frame<52;frame++){
   paging=0xb0;ram[0x7ee]=0xff;ram[0x7ef]=7;z->sp=0x7ee;z->pc=compose;unsigned long start=z->cyc;
   composing=1;while(z->pc!=0x7ff&&z->cyc-start<2000000)tracked_step(z);composing=0;
   if(z->pc!=0x7ff||check())bad++;
   if(frame>=2)ticks+=z->cyc-start;
  }
  printf("BENCH sprites=%d frames=50 cycles_per_frame=%.1f indexed_prefixes=%lu\n",n,ticks/50.0,indexed_prefixes-oldprefix);
 }
 /* Moving scenes: every sprite moves each frame (worst case), then a randomised stress run. */
 for(int mode=0;mode<2;mode++){
  int n=16;memset(ram+0xfc00,0,512);memset(ram+0x5800,0,64);memset(ram+0x5900,0,64);reset_state();
  memcpy(video+1536,ram+0x2000,12288);memcpy(video+3*16384+1536,ram+0x2000,12288);
  srand(12345);int nmeta=136;
  for(int i=0;i<n;i++){int e=0xfc00+32*i;int meta=0xe400+10*(mode?rand()%nmeta:5);ram[e]=1;ram[e+1]=1+(i%8)*28;ram[e+2]=32+(i/8)*48;ram[e+3]=ram[meta];ram[e+4]=ram[meta+1];ram[e+5]=(uint8_t[]){0xff,0xf0,0x0f,0xff}[i%4];ram[e+7]=(meta+3)&255;ram[e+8]=(meta+3)>>8;}
  unsigned long ticks=0,oldprefix=indexed_prefixes;int mbad=0,frames=mode?600:52;
  for(int frame=0;frame<frames;frame++){
   for(int i=0;i<n;i++){int e=0xfc00+32*i;
    if(!mode){ram[e+1]+=1;ram[e+2]=32+(i/8)*48+(frame&3);}
    else if(rand()%3==0){int r=rand()%12;
     if(r<6){ram[e+1]=rand()%256;ram[e+2]=rand()%200;ram[e]=(ram[e]&~128)|((rand()%8==0)?128:0);}
     else if(r<8){ram[e+1]+=rand()%5-2;ram[e+2]+=rand()%5-2;}
     else if(r==8)ram[e]^=1;
     else if(r==9)ram[e+30]^=128;
     else if(r==10)ram[e+5]=(uint8_t[]){0,0xf0,0x0f,0xff}[rand()%4];
     else{int meta=0xe400+10*(rand()%nmeta);ram[e+3]=ram[meta];ram[e+4]=ram[meta+1];ram[e+7]=(meta+3)&255;ram[e+8]=(meta+3)>>8;}}
   }
   paging=0xb0;ram[0x7ee]=0xff;ram[0x7ef]=7;z->sp=0x7ee;z->pc=compose;unsigned long start=z->cyc;
   composing=1;while(z->pc!=0x7ff&&z->cyc-start<2000000)tracked_step(z);composing=0;
   if(z->pc!=0x7ff||check())mbad++;
   if(frame>=2)ticks+=z->cyc-start;
  }
  printf("BENCH %s frames=%d cycles_per_frame=%.1f failures=%d indexed_prefixes=%lu\n",mode?"stress":"moving16",frames,ticks/(frames-2.0),mbad,indexed_prefixes-oldprefix);bad+=mbad;
 }
 printf("BENCH failures=%d visible_sprite_writes=%lu\n",bad,visible_writes);return (bad||visible_writes||indexed_prefixes)?1:0;
}
int main(int argc,char**argv){if(argc<4)return 2;FILE*f=fopen(argv[1],"rb");if(!f)return 3;fseek(f,144,SEEK_SET);size_t loaded=fread(ram+0x19ef,1,65536-0x19ef,f);if(!loaded)return 4;fclose(f);z80 z;z80_init(&z);z.read_byte=readmem;z.write_byte=writemem;z.port_in=input;z.port_out=output;z.pc=strtol((char*)ram+0x19f8,0,10);if(getenv("STATE_LO")&&getenv("STATE_HI")){state_lo=strtol(getenv("STATE_LO"),0,16);state_hi=strtol(getenv("STATE_HI"),0,16);}if(getenv("COMPOSE_PC"))watched_compose=strtol(getenv("COMPOSE_PC"),0,16);unsigned long fc=0;FILE*hf=fopen(getenv("HASHOUT"),"w");int done=strtol(argv[2],0,16),frame=strtol(argv[3],0,16),checks=0,bad=0,phase=0;unsigned long start=0,frames=0;for(int n=0;n<50000000;n++){if(z.cyc>4000000&&phase==0){keys=1;phase=1;}if(z.cyc>6000000&&phase==1){keys=0;phase=2;}if(z.cyc>10000000&&phase==2){keys=2;phase=3;start=z.cyc;}if(fc>=380)keys=3;if(fc>=540)keys=2;if(argc==5&&z.pc==0x8641)ram[0x5b04]=strtol(argv[4],0,0);if(phase==3&&z.pc==frame)frames++;if(z.pc==done)fc++;if(phase==3&&z.pc==done){{unsigned long h=1469598103934665603UL;for(int i=1536;i<1536+64*192;i++)h=(h^video[display*16384+i])*1099511628211UL;unsigned long hh=1469598103934665603UL;for(int i=1536+168*64;i<1536+192*64;i++)hh=(hh^video[display*16384+i])*1099511628211UL;unsigned long g=1469598103934665603UL;for(int i=0xaaed;i<0xaaed+752;i++)g=(g^ram[i])*1099511628211UL;for(int i=0xe180;i<0xe200;i++)g=(g^ram[i])*1099511628211UL;for(int i=0xfc00;i<0xfe00;i++)g=(g^ram[i])*1099511628211UL;unsigned long g1=1469598103934665603UL,g2=g1,g3=g1;for(int i=0xaaed;i<0xaaed+752;i++)g1=(g1^ram[i])*1099511628211UL;for(int i=0xe180;i<0xe200;i++)g2=(g2^ram[i])*1099511628211UL;for(int i=0xfc00;i<0xfe00;i++)g3=(g3^ram[i])*1099511628211UL;if(getenv("DUMPFRAME")&&fc==(unsigned long)atoi(getenv("DUMPFRAME"))){FILE*df=fopen(getenv("DUMPFILE"),"wb");fwrite(ram,1,65536,df);fclose(df);}fprintf(hf,"%lu %lx %lx %lx %lx %lx\n",fc,h,hh,g1,g2,g3);}int q=check();checks++;if(ram[0xfde2]<miny)miny=ram[0xfde2];if(ram[0xfde2]>maxy)maxy=ram[0xfde2];roomset[ram[0x5b04]]=1;if(q){bad++;if(bad<8)printf("BAD frame=%d bytes=%d room=%d player=%d,%d\n",checks,q,ram[0x5b04],ram[0xfde1],ram[0xfde2]);}if(checks%6==0){char name[128];sprintf(name,"build/native-frame-%04d.vram",checks);f=fopen(name,"wb");fwrite(video+display*16384,1,16384,f);fclose(f);}}if(z.pc==watched_compose)composing=1;if(z.pc==done)composing=0;if(ram[z.pc]==0xed&&ram[(uint16_t)(z.pc+1)]==0x5f){static unsigned lcg=12345;lcg=lcg*1103515245u+12345u;z.r=(lcg>>16)&0x7f;}if(getenv("WATCH")&&z.pc==strtol(getenv("WATCH"),0,16)){static int wn=0;static FILE*wf=0;if(!wf)wf=fopen("watch.out","w");if(wn<3000){fprintf(wf,"%lu %d\n",(unsigned long)z.cyc,z.a);wn++;}}tracked_step(&z);if(argc>5&&z.pc==strtol(argv[5],0,16)){if(getenv("BENCHMARK"))return run_bench(&z,strtol(argv[4],0,16));return run_units(&z,strtol(argv[4],0,16),strtol(argv[6],0,16));}if(fc>900)break;}printf("checks=%d mismatched_frames=%d frames=%lu cycles=%lu fps=%.2f pc=%04x player=%d,%d\n",checks,bad,frames,z.cyc-start,frames*3125000.0/(z.cyc-start),z.pc,ram[0xfde1],ram[0xfde2]);printf("COMPOSE_SHARE cycles_in_compose=%lu of %lu\n",comp_cyc,(unsigned long)(z.cyc-start));printf("player_y=%d..%d rooms:",miny,maxy);for(int i=0;i<256;i++)if(roomset[i])printf(" %d",i);puts("");f=fopen("build/native-final.ram","wb");fwrite(ram,1,65536,f);fclose(f);f=fopen("build/native-final.vram","wb");fwrite(video,1,65536,f);fclose(f);printf("visible_sprite_writes=%lu flips=%lu indexed_prefixes=%lu\n",visible_writes,flips,indexed_prefixes);return (bad||visible_writes||indexed_prefixes)?1:0;}
