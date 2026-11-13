#include "minecraft.h"
#include "video.h"
#include <stdio.h>
#include <stdlib.h>
int main(int argc,char **argv){int frames=180; const char *out="fpgacraft.ppm"; if(argc>1)frames=atoi(argv[1]); if(argc>2)out=argv[2]; Game g; game_init(&g,20261112u); video_open(); for(int i=0;i<frames;i++)game_step(&g,(i/90)%2,(i/90+1)%2,(i%45)==0); if(video_frame(&g,out)){perror(out);return 1;} printf("Imagem gerada: %s | jogador=(%d,%d) | terreno %dx%d\n",out,g.p.x,g.p.y,MW,MH); video_close(); return 0;}
