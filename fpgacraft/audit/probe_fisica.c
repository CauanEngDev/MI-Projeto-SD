#include "minecraft.h"
#include <stdio.h>
static int surface(Game*g,int x){for(int y=0;y<MH;y++)if(g->map[y][x])return y;return -1;}
int main(void){
  Game g; game_init(&g,20261112u);
  printf("spawn x=%d y=%d | superficie coluna %d = linha %d\n",g.p.x,g.p.y,g.p.x/8,surface(&g,g.p.x/8));
  puts("--- queda parado, 60 quadros (y,vy,on_ground) ---");
  int changes=0,prev_og=-1;
  for(int i=0;i<60;i++){ game_step(&g,0,0,0);
    if(i<30||i%10==0) printf("f%02d y=%3d vy=%2d og=%d\n",i,g.p.y,g.p.vy,g.p.on_ground);
    if(g.p.on_ground!=prev_og){changes++;prev_og=g.p.on_ground;} }
  printf("transicoes de on_ground em 60 quadros: %d\n",changes);
  int feet=(g.p.y+14)/8; printf("pe do jogador (linha) = %d ; y final=%d\n",feet,g.p.y);
  puts("--- altura da superficie ao longo do mapa ---");
  int maxstep=0; for(int x=0;x<MW;x++){int s=surface(&g,x); if(x) {int d=surface(&g,x-1)-s; if(d<0)d=-d; if(d>maxstep)maxstep=d;} printf("%d ",s);} 
  printf("\nmaior degrau entre colunas vizinhas: %d blocos\n",maxstep);
  /* altura máxima do pulo */
  Game h; game_init(&h,20261112u); for(int i=0;i<200;i++)game_step(&h,0,0,0);
  int y0=h.p.y,miny=y0; game_step(&h,0,0,1); for(int i=0;i<40;i++){ if(h.p.y<miny)miny=h.p.y; game_step(&h,0,0,0);} 
  printf("pulo: y0=%d minimo=%d altura=%d px (%.2f blocos)\n",y0,miny,y0-miny,(y0-miny)/8.0);
  /* colocar bloco dentro do jogador */
  Game k; game_init(&k,20261112u); for(int i=0;i<200;i++)game_step(&k,0,0,0);
  k.p.selected=DIRT; unsigned before=k.p.blocks[DIRT];
  int sx=k.p.x+6-k.cam_x, sy=k.p.y+4-k.cam_y; game_place(&k,sx,sy);
  printf("place sobre o proprio jogador: bloco em (%d,%d)=%d, dirt %u->%u (aceito=%s)\n",(k.p.x+6)/8,(k.p.y+4)/8,k.map[(k.p.y+4)/8][(k.p.x+6)/8],before,k.p.blocks[DIRT],before!=k.p.blocks[DIRT]?"SIM":"nao");
  /* mineração: alcance e sem checagem de linha de visada */
  printf("selected fixo: %d (nenhuma API para trocar bloco)\n",k.p.selected);
  return 0;}
