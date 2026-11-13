#include "video.h"
#include <stdio.h>
#include <stdint.h>
static const uint8_t rgb[8][3]={{25,35,55},{75,175,65},{130,82,48},{105,108,115},{30,30,30},{130,82,48},{55,155,55},{25,25,35}};
int video_open(void){return 0;} void video_close(void){}
int video_frame(Game *g,const char *path){ static uint8_t im[VW*TS*VH*TS*3]; int w=VW*TS,h=VH*TS;
 for(int y=0;y<h;y++)for(int x=0;x<w;x++){int wx=(g->cam_x+x)/TS,wy=(g->cam_y+y)/TS; int b=(wx>=0&&wx<MW&&wy>=0&&wy<MH)?g->map[wy][wx]:0; const uint8_t *c=rgb[b]; int k=(y*w+x)*3; im[k]=c[0];im[k+1]=c[1];im[k+2]=c[2]; if(b==GRASS&&(y%TS)<2){im[k]=65;im[k+1]=205;im[k+2]=70;} }
 int px=g->p.x-g->cam_x,py=g->p.y-g->cam_y; for(int y=0;y<15;y++)for(int x=0;x<12;x++){int xx=px+x,yy=py+y;if(xx>=0&&xx<w&&yy>=0&&yy<h){int k=(yy*w+xx)*3; im[k]=220;im[k+1]=(y<4?190:115);im[k+2]=80;}}
 FILE*f=fopen(path,"wb"); if(!f)return -1; fprintf(f,"P6\n%d %d\n255\n",w,h); fwrite(im,1,sizeof im,f); fclose(f); return 0; }
