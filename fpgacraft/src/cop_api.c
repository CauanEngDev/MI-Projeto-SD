#define _GNU_SOURCE
#include <stdio.h>
#include "cop_api_c.h"
#include "hps_bridges.h"
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <errno.h>
#include <stddef.h>
#define OP_ADD 1
#define OP_LSL 4
#define OP_LSR 5
#define OP_PASS 6
#define OP_SET_PALETTE 7
#define OP_DRAW_RECT 8
#define OP_SET_SPR_POS 10
#define OP_SET_SPR_ATTR 11
#define OP_SET_TILEMAP 12
#define OP_SCROLL_BG 13
#define OP_WRITE_SPR 14
#define OP_WRITE_TILE 15
#define OP_DRAW_BG 16
#define OP_DRAW_SPR 17
#define OP_HALT 19
#define RA 0
#define RB 1
#define XZR 31
#define TIMEOUT 0x200000u
static volatile uint32_t *regp(void *b,unsigned off){return (volatile uint32_t*)((uintptr_t)b+off);}
void *hps_open(void){int fd=open("/dev/mem",O_RDWR|O_SYNC);if(fd<0)return NULL;void*p=mmap(NULL,HPS_LW_SPAN,PROT_READ|PROT_WRITE,MAP_SHARED,fd,HPS_LW_BASE);close(fd);return p==MAP_FAILED?NULL:p;}
int hps_close(void*b){return (!b||munmap(b,HPS_LW_SPAN))?-1:0;}
uint32_t cop_status(void*b){return *regp(b,COPROC_REG_STATUS);} uint32_t cop_frame_count(void*b){return cop_status(b)>>16;}
int cop_push(void*b,uint32_t w){for(uint32_t i=0;i<TIMEOUT;i++){if(!(cop_status(b)&COPROC_ST_FULL)){*regp(b,COPROC_REG_CMD)=w;return 0;}}return -1;}
int cop_init(void *b) {
    uint32_t id = *regp(b, COPROC_REG_ID);
    uint32_t status = cop_status(b);

    fprintf(stderr, "[DEBUG] ID: 0x%08X\n", id);
    fprintf(stderr, "[DEBUG] STATUS inicial: 0x%08X\n", status);

    if (id != COPROC_ID_VALUE) {
        fprintf(stderr, "[DEBUG] ID esperado: 0x%08X\n",
                COPROC_ID_VALUE);
        return -1;
    }

    *regp(b, COPROC_REG_CTRL) = COPROC_CTRL_SOFT_RESET;

    for (uint32_t i = 0; i < TIMEOUT; i++) {
        status = cop_status(b);

        if (!(status & COPROC_ST_INIT_BUSY) &&
            (status & COPROC_ST_PLL_LOCKED)) {
            fprintf(stderr, "[DEBUG] Inicializacao concluida.\n");
            return 0;
        }
    }

    fprintf(stderr, "[DEBUG] STATUS final: 0x%08X\n", status);
    return -2;
}
static int alu(void*b,unsigned op,unsigned rd,unsigned rn,unsigned imm){uint32_t w=(op<<27)|(1u<<26)|((rd&31u)<<21)|((rn&63u)<<15)|(((rd>>5)&1u)<<14)|(imm&0xfffu);return cop_push(b,w);}
static int gins(void*b,unsigned op,unsigned ra,unsigned rb){return cop_push(b,(op<<27)|(ra<<21)|(rb<<15));}
static int loadreg(void*b,unsigned r,uint32_t v){
 if(v<=4095)return alu(b,OP_PASS,r,XZR,v);
 if(v<=0xFFFFFFu){if(alu(b,OP_PASS,r,XZR,v>>12)<0)return -1;if(alu(b,OP_LSL,r,r,12)<0)return -1;return (v&4095u)?alu(b,OP_ADD,r,r,v&4095u):0;}
 if(alu(b,OP_PASS,r,XZR,v>>20)<0)return -1;
 if(alu(b,OP_LSL,r,r,12)<0)return -1;
 if(alu(b,OP_ADD,r,r,(v>>8)&4095u)<0)return -1;
 if(alu(b,OP_LSL,r,r,8)<0)return -1;
 return (v&255u)?alu(b,OP_ADD,r,r,v&255u):0;
}
static int setab(void*b,unsigned op,uint32_t a,uint32_t c){if(loadreg(b,RA,a)<0||loadreg(b,RB,c)<0)return -1;return gins(b,op,RA,RB);}
uint32_t cop_wait_frame(void*b,uint32_t old){for(uint32_t i=0;i<TIMEOUT;i++){uint32_t f=cop_frame_count(b);if(f!=old)return f;}return 0xffffffffu;}
int cop_draw_bg(void*b){return cop_push(b,OP_DRAW_BG<<27);} int cop_draw_sprites(void*b){return cop_push(b,OP_DRAW_SPR<<27);} int cop_halt(void*b){return cop_push(b,OP_HALT<<27);} uint32_t cop_present(void*b,uint32_t f){if(cop_halt(b)<0)return 0xffffffffu;return cop_wait_frame(b,f);}
int cop_set_palette(void*b,uint32_t s,uint32_t i,uint32_t rgb){if(s>1||i>255||rgb>511)return -3;return setab(b,OP_SET_PALETTE,(s<<8)|i,rgb);}
int cop_set_tilemap(void*b,uint32_t p,uint32_t id){if(p>=1200||id>255)return -3;return setab(b,OP_SET_TILEMAP,p,id);}
static int write_pixels(void*b,unsigned op,uint32_t addr,const uint8_t*p,unsigned n){if(loadreg(b,RA,addr)<0)return -1;unsigned last=256;for(unsigned i=0;i<n;i++){unsigned c=p[i];if(c!=last){if(alu(b,OP_PASS,RB,XZR,c)<0)return -1;last=c;}if(gins(b,op,RA,RB)<0)return -1;if(i+1<n&&alu(b,OP_ADD,RA,RA,1)<0)return -1;}return 0;}
int cop_write_tile_data(void*b,uint32_t id,const uint8_t*p){if(id>=256||!p)return -3;return write_pixels(b,OP_WRITE_TILE,id*64,p,64);}
int cop_write_sprite_data(void*b,uint32_t id,const uint8_t*p){if(id>=64||!p)return -3;return write_pixels(b,OP_WRITE_SPR,id*256,p,256);}
int cop_set_sprite_pos(void*b,uint32_t id,uint32_t x,uint32_t y){if(id>=32||x>=512||y>=256)return -3;return setab(b,OP_SET_SPR_POS,id,(y<<9)|x);}
int cop_set_sprite_attr(void*b,uint32_t id,uint32_t a){if(id>=32||a>=0x8000)return -3;return setab(b,OP_SET_SPR_ATTR,id,a);}
int cop_draw_rect(void*b,uint32_t x0,uint32_t y0,uint32_t x1,uint32_t y1,uint32_t c){if(x0>=320||x1>=320||y0>=240||y1>=240||c>=512)return -3;unsigned regs[]={37,38,39,40,43},vals[]={x0,y0,x1,y1,c};for(int i=0;i<5;i++)if(loadreg(b,regs[i],vals[i])<0)return -1;return cop_push(b,OP_DRAW_RECT<<27);}
int cop_scroll_bg(void*b,uint32_t x,uint32_t y){if(x>=320||y>=240)return -3;if(setab(b,OP_SCROLL_BG,x,0)<0)return -1;return setab(b,OP_SCROLL_BG,y,1);}
