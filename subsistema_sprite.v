module subsistema_sprite(
    input wire clk,
    input wire reset,

    // Avalon-MM: escrita da CPU nos atributos
    input wire        attr_wr_en,
    input wire [4:0]  attr_wr_addr,
    input wire [31:0] attr_wr_data,

    // Avalon-MM: escrita da CPU nos padrões gráficos
    input wire        pattern_wr_en,
    input wire [13:0] pattern_wr_addr,
    input wire [7:0]  pattern_wr_data,

    // Leitura da palette_ram (2 paletas x 256 cores)
    output wire [8:0]  palette_rd_addr,
    input  wire [8:0]  palette_rd_data,

    // Interface de escrita no framebuffer
    output wire         fb_we,
    output wire [8:0]   fb_wr_x,
    output wire [7:0]   fb_wr_y,
    output wire [8:0]   fb_wr_data,

    input  wire start,
    output wire busy,
    output wire done
);

    wire [4:0]  attr_rd_addr;
    wire [31:0] attr_rd_data;
    wire [13:0] pattern_rd_addr;
    wire [7:0]  pattern_rd_data;

    sprite_attribute_ram u_attr_ram (
        .clock     (clk),
        .data      (attr_wr_data),
        .wraddress (attr_wr_addr),
        .wren      (attr_wr_en),
        .rdaddress (attr_rd_addr),
        .q         (attr_rd_data)
    );

    sprite_pattern_ram u_pattern_ram (
        .clock     (clk),
        .data      (pattern_wr_data),
        .wraddress (pattern_wr_addr),
        .wren      (pattern_wr_en),
        .rdaddress (pattern_rd_addr),
        .q         (pattern_rd_data)
    );

    motor_sprite u_engine (
        .clk (clk),
        .reset (reset),
        .attr_rd_addr    (attr_rd_addr),
        .attr_rd_data    (attr_rd_data),
        .pattern_rd_addr (pattern_rd_addr),
        .pattern_rd_data (pattern_rd_data),
        .palette_rd_addr (palette_rd_addr),
        .palette_rd_data (palette_rd_data),
        .fb_we      (fb_we),
        .fb_wr_x    (fb_wr_x),
        .fb_wr_y    (fb_wr_y),
        .fb_wr_data (fb_wr_data),
        .start (start),
        .busy  (busy),
        .done  (done)
    );

endmodule