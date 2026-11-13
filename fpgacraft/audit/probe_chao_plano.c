#include "minecraft.h"
#include <stdio.h>
int main(void){
  Game g; game_init(&g,20261112u);
  g.p.x=15*8; g.p.y=0;           /* colunas 15 e 16: ambas superficie na linha 16 -> chao em y=128 */
  printf("col15 topo=%d col16 topo=%d\n",g.map[16][15]?16:-1,g.map[16][16]?16:-1);
  int tr=0,prev=-1;
  for(int i=0;i<120;i++){game_step(&g,0,0,0); if(i>=100)printf("f%d y=%d og=%d\n",i,g.p.y,g.p.on_ground); if(g.p.on_ground!=prev){tr++;prev=g.p.on_ground;}}
  printf("y esperado em repouso = 128-15 = 113 ; transicoes on_ground=%d\n",tr);
  return 0;}
