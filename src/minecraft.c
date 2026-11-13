#include "minecraft.h"
#include <string.h>

static uint32_t rnd(Game *g){ uint32_t x=g->rng; x^=x<<13; x^=x>>17; x^=x<<5; return g->rng=x; }
static int solid(const Game *g,int x,int y){ if(x<0||x>=MW||y<0||y>=MH)return 1; return g->map[y][x]!=EMPTY; }
static int collides(const Game *g,int px,int py){ int x0=px/TS,y0=py/TS,x1=(px+11)/TS,y1=(py+14)/TS; return solid(g,x0,y0)||solid(g,x1,y0)||solid(g,x0,y1)||solid(g,x1,y1); }
void game_init(Game *g,uint32_t seed){ memset(g,0,sizeof *g); g->rng=seed?seed:0x91E10DA5u;
 for(int x=0;x<MW;x++){ int h=13+(int)(rnd(g)%5); for(int y=h;y<MH;y++){ if(y==h)g->map[y][x]=GRASS; else if(y<h+4)g->map[y][x]=DIRT; else g->map[y][x]=(rnd(g)%19==0)?COAL:STONE; } }
 for(int x=0;x<MW;x++)g->map[MH-1][x]=BEDROCK;
 /* arvore simples */ for(int x=8;x<MW-5;x+=13){ int y=0; while(y<MH&&g->map[y][x]==EMPTY)y++; if(y>3){ for(int k=-1;k<=1;k++)g->map[y-4][x+k]=LEAF; g->map[y-5][x]=LEAF; g->map[y-1][x]=WOOD; g->map[y-2][x]=WOOD; g->map[y-3][x]=WOOD; } }
 g->p.x=MW*TS/2; g->p.y=6*TS; g->p.selected=DIRT; g->p.blocks[DIRT]=20; g->p.blocks[STONE]=8; g->p.blocks[WOOD]=4; g->p.blocks[COAL]=0;
}
void game_step(Game *g,int left,int right,int jump){ Player *p=&g->p; p->vx=(right-left)*2; if(jump&&p->on_ground){p->vy=-6;p->on_ground=0;} p->vy+=1; if(p->vy>7)p->vy=7;
 int nx=p->x+p->vx; if(!collides(g,nx,p->y))p->x=nx;
 int ny=p->y+p->vy; if(!collides(g,p->x,ny)){p->y=ny;p->on_ground=0;} else { if(p->vy>0){p->on_ground=1; p->y=(ny/TS)*TS-15;} p->vy=0; }
 if(p->x<0) p->x=0;
 if(p->x>MW*TS-12) p->x=MW*TS-12;
 if(p->y>MH*TS-16){p->y=MH*TS-16;p->vy=0;p->on_ground=1;}
 g->cam_x=p->x+6-VW*TS/2; g->cam_y=p->y+7-VH*TS/2; if(g->cam_x<0)g->cam_x=0; if(g->cam_y<0)g->cam_y=0; if(g->cam_x>MW*TS-VW*TS)g->cam_x=MW*TS-VW*TS; if(g->cam_y>MH*TS-VH*TS)g->cam_y=MH*TS-VH*TS;
}
void game_mine(Game *g,int sx,int sy){ int x=(g->cam_x+sx)/TS,y=(g->cam_y+sy)/TS; if(x<0||x>=MW||y<0||y>=MH)return; if((x*TS-(g->p.x+6))*(x*TS-(g->p.x+6))+(y*TS-(g->p.y+7))*(y*TS-(g->p.y+7))> (5*TS)*(5*TS))return; int b=g->map[y][x]; if(b==EMPTY||b==BEDROCK)return; g->map[y][x]=EMPTY; if(b<8)g->p.blocks[b]++; }
void game_place(Game *g,int sx,int sy){ int x=(g->cam_x+sx)/TS,y=(g->cam_y+sy)/TS; int b=g->p.selected; if(x<0||x>=MW||y<0||y>=MH||b<=EMPTY||b>=8||!g->p.blocks[b]||g->map[y][x])return; if((x*TS-(g->p.x+6))*(x*TS-(g->p.x+6))+(y*TS-(g->p.y+7))*(y*TS-(g->p.y+7))>(5*TS)*(5*TS))return; g->map[y][x]=(uint8_t)b; g->p.blocks[b]--; }
