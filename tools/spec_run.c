#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "z80.h"
static uint8_t ram[65536];int keys=0;
static uint8_t rd(void*u,uint16_t a){return ram[a];}
static void wr(void*u,uint16_t a,uint8_t v){if(a>=0x4000)ram[a]=v;}
static uint8_t in(z80*z,uint8_t p){ /* ULA keyboard: z->b holds high address byte? use z->b */
 uint8_t v=0xff,hi=z->b; if(p==0xfe){ if(!(hi&0x08)&&(keys&1))v&=~1; /* space row 7FFE */
  if(!(hi&0x02)&&(keys&2))v&=~1; /* A..: row FD, bit0 = A */ 
  if(!(hi&0x20)&&(keys&4))v&=~1;} return v;}
static void out(z80*z,uint8_t p,uint8_t v){}
int main(int argc,char**argv){FILE*f=fopen(argv[1],"rb");fread(ram+0x4000,1,49152,f);fclose(f);memset(ram,0xc9,0x4000);ram[0x1f54]=0x37;ram[0x39ff]=0xf4;ram[0x3a00]=0xff;{uint8_t px[]={0x47,0xA7,0x1F,0x37,0x1F,0xA7,0x1F,0xA8,0xE6,0xF8,0xA8,0x67,0x79,0x07,0x07,0x07,0xA8,0xE6,0xC7,0xA8,0x07,0x07,0x6F,0x79,0xE6,0x07,0xC9};memcpy(ram+0x22b0,px,sizeof px);}
 z80 z;z80_init(&z);z.read_byte=rd;z.write_byte=wr;z.port_in=in;z.port_out=out;z.pc=0x7da3;
 unsigned long next=69888,last=0,n=0,tot=0;static unsigned long pcy[65536];int shown=0;static unsigned hist[64];int hi_=0;int mode=argc>2?atoi(argv[2]):0;
 for(unsigned long i=0;i<400000000;i++){
  if(z.cyc>next){next+=69888;if(z.iff1)z80_gen_int(&z,0xff);}
  if(z.cyc<5000000)keys=1;else keys=mode?(mode==1?2:4):0; /* hold left/right? */
  if(0){printf("7dc3 cyc=%lu room=%d\n",(unsigned long)z.cyc,ram[0x5b04]);}
  if(z.pc==0x7dc3){ if(z.cyc>8000000&&z.cyc<60000000){ if(last){tot+=z.cyc-last;n++;} last=z.cyc;} }
  if(z.pc<0x4000&&z.pc!=0x38&&shown<2){shown++;printf("ROM pc=%04x sp=%04x ret=%02x%02x cyc=%lu\n",z.pc,z.sp,ram[z.sp+1],ram[z.sp],(unsigned long)z.cyc);}hist[hi_++&63]=z.pc;unsigned long c0_=z.cyc;uint16_t p0_=z.pc;if(z.pc==0x8666||z.pc==0x7da3||z.pc==0x85b4||z.pc==0x9907||z.pc==0x7dcf||z.pc==0x88a3&&shown<0){shown++;printf("at %04x cyc=%lu\n",z.pc,(unsigned long)z.cyc);}z80_step(&z);if(z.cyc>8000000&&z.cyc<60000000)pcy[p0_]+=z.cyc-c0_; if(z.cyc>120000000)break;}
 for(int q=0;q<64;q++)printf("%04x ",hist[(hi_+q)&63]);puts("");{FILE*pf=fopen("spec_prof.txt","w");for(int i=0;i<65536;i++)if(pcy[i])fprintf(pf,"%04x %lu\n",i,pcy[i]);fclose(pf);}printf("A=%02x B=%02x C=%02x D=%02x E=%02x H=%02x L=%02x\n",z.a,z.b,z.c,z.d,z.e,z.h,z.l);printf("pc=%04x halted=%d iff1=%d\n",z.pc,z.halted,z.iff1);printf("iterations=%lu avg_cycles=%.0f => %.2f fps at 3.5MHz; room=%d player=%d,%d\n",n,n?(double)tot/n:0,n?3500000.0*n/tot:0,ram[0x5b04],ram[0xfde1],ram[0xfde2]);}
