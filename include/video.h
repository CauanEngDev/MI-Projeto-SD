#ifndef VIDEO_H
#define VIDEO_H
#include "minecraft.h"
int video_open(void);
void video_close(void);
int video_frame(Game *g,const char *path);
#endif
