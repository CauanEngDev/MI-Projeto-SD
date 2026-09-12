module sprite_spawner (
    input wire clk,
    input wire reset,
    input wire spawn_pulse,
    input wire [8:0] spawn_x,

    output reg        attr_wr_en,
    output reg [4:0]  attr_wr_addr,
    output reg [31:0] attr_wr_data
);
    localparam FIRST_FREE_SLOT = 5'd6; // 0-4 = testes fixos, 5 = controlavel
    localparam LAST_SLOT       = 5'd31;

    reg [4:0] next_slot;

    always @(posedge clk) begin
        if (reset) begin
            next_slot  <= FIRST_FREE_SLOT;
            attr_wr_en <= 1'b0;
        end else begin
            attr_wr_en <= 1'b0;
            if (spawn_pulse && next_slot <= LAST_SLOT) begin
                attr_wr_en   <= 1'b1;
                attr_wr_addr <= next_slot;
                // enable=1 priority=4 sem flip pattern_index=0 (quadrado preenchido)
                attr_wr_data <= {1'b1, 5'd4, 1'b0, 1'b0, 1'b0, 6'd0, 8'd100, spawn_x};
                next_slot    <= next_slot + 5'd1;
            end
        end
    end
endmodule