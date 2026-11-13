#ifndef COP_API_C_H
#define COP_API_C_H
#include <stdint.h>
#include "cop_api.h"
void *hps_open(void); int hps_close(void *base); int cop_init(void *base);
uint32_t cop_status(void *base); uint32_t cop_frame_count(void *base); uint32_t cop_wait_frame(void *base,uint32_t old); int cop_push(void *base,uint32_t word);
int cop_draw_bg(void *base); int cop_draw_sprites(void *base); int cop_halt(void *base); uint32_t cop_present(void *base,uint32_t old);
int cop_set_palette(void*,uint32_t,uint32_t,uint32_t); int cop_set_tilemap(void*,uint32_t,uint32_t); int cop_write_tile_data(void*,uint32_t,const uint8_t*); int cop_write_sprite_data(void*,uint32_t,const uint8_t*);
int cop_set_sprite_pos(void*,uint32_t,uint32_t,uint32_t); int cop_set_sprite_attr(void*,uint32_t,uint32_t); int cop_draw_rect(void*,uint32_t,uint32_t,uint32_t,uint32_t,uint32_t); int cop_scroll_bg(void*,uint32_t,uint32_t);
#endif
