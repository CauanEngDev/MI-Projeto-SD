// Memories and motor must share clk. Addresses remain stable while waiting.
// Defaults tolerate synchronous RAMs with registered address AND output.
// The extra wait is also safe for one-cycle RAMs (at lower throughput).
module motor_background #(
    parameter TILE_EXTRA_WAIT = 1,
    parameter PALETTE_EXTRA_WAIT = 1
) (
    input wire clk,
    input wire reset,

    input wire       scroll_wr_en,
    input wire       scroll_sel,
    input wire [8:0] scroll_wr_data,

    // Automatic movement, once per accepted start.
    input wire       scroll_auto_en,
    input wire       scroll_auto_axis, // 0: horizontal; 1: vertical
    input wire       scroll_auto_dir,  // 0: image left/up; 1: right/down
    input wire [7:0] scroll_auto_step, // pixels per rendered frame; 0: stopped

    output reg [10:0] tile_rd_addr,
    input wire [7:0] tile_rd_data,
    output reg [13:0] pattern_rd_addr,
    input wire [7:0] pattern_rd_data,
    output reg [8:0] palette_rd_addr,
    input wire [8:0] palette_rd_data,

    output reg fb_we,
    output reg [8:0] fb_wr_x,
    output reg [7:0] fb_wr_y,
    output reg [8:0] fb_wr_data,

    input wire start,
    output wire busy,
    output reg done
);
    localparam S_IDLE           = 4'd0,
               S_ROW_CHECK      = 4'd1,
               S_PREFETCH_SET   = 4'd2,
               S_PREFETCH_WAIT  = 4'd3,
               S_PREFETCH_STORE = 4'd4,
               S_PATTERN_SET    = 4'd5,
               S_PATTERN_WAIT   = 4'd6,
               S_PALETTE_SET    = 4'd7,
               S_PALETTE_WAIT   = 4'd8,
               S_WRITE          = 4'd9,
               S_DONE           = 4'd10,
               S_PATTERN_WAIT2  = 4'd11,
               S_PREFETCH_WAIT2 = 4'd12,
               S_PALETTE_WAIT2  = 4'd13;

    reg [3:0] state;
    assign busy = (state != S_IDLE);
    wire accept_start = start && (state == S_IDLE);


	// Um novo frame pode ser iniciado externamente ou automaticamente.
	 wire render_start = accept_start;

    reg [8:0] scroll_x, next_scroll_x;
    reg [7:0] scroll_y, next_scroll_y;
    // Snapshot: writes during rendering apply to the next frame.
    reg [8:0] frame_scroll_x;
    reg [7:0] frame_scroll_y;
    reg [9:0] motion_x;
    reg [8:0] motion_y;
    wire [7:0] step_y = (scroll_auto_step >= 8'd240)
                         ? scroll_auto_step - 8'd240 : scroll_auto_step;

    always @* begin
        next_scroll_x = scroll_x;
        next_scroll_y = scroll_y;
        motion_x = 10'd0;
        motion_y = 9'd0;

        // Explicit writes take precedence over automatic movement.
        if (scroll_wr_en) begin
            if (scroll_sel)
                next_scroll_y = (scroll_wr_data[7:0] >= 8'd240)
                              ? scroll_wr_data[7:0] - 8'd240
                              : scroll_wr_data[7:0];
            else
                next_scroll_x = (scroll_wr_data >= 9'd320)
                              ? scroll_wr_data - 9'd320 : scroll_wr_data;
        end else if (render_start && scroll_auto_en) begin
            if (!scroll_auto_axis) begin
                // Add one full period before subtraction to avoid underflow.
                if (scroll_auto_dir)
                    motion_x = {1'b0, scroll_x} + 10'd320
                             - {2'b00, scroll_auto_step};
                else
                    motion_x = {1'b0, scroll_x} + {2'b00, scroll_auto_step};
                if (motion_x >= 10'd320) motion_x = motion_x - 10'd320;
                next_scroll_x = motion_x[8:0];
            end else begin
					//vertical
                if (scroll_auto_dir)
                    motion_y = {1'b0, scroll_y} + 9'd240 - {1'b0, step_y};
                else
                    motion_y = {1'b0, scroll_y} + {1'b0, step_y};
                if (motion_y >= 9'd240) motion_y = motion_y - 9'd240;
                next_scroll_y = motion_y[7:0];
            end
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            scroll_x <= 9'd0;
            scroll_y <= 8'd0;
            frame_scroll_x <= 9'd0;
            frame_scroll_y <= 8'd0;
        end else begin
            scroll_x <= next_scroll_x;
            scroll_y <= next_scroll_y;
            if (render_start) begin
					 frame_scroll_x <= next_scroll_x;
					 frame_scroll_y <= next_scroll_y;
				end
        end
    end

    reg [8:0] screen_x;
    reg [7:0] screen_y;
    wire [9:0] sum_x = {1'b0, screen_x} + {1'b0, frame_scroll_x};
    wire [8:0] sum_y = {1'b0, screen_y} + {1'b0, frame_scroll_y};
    wire [9:0] wrapped_x_full = (sum_x >= 10'd320) ? sum_x - 10'd320 : sum_x;
    wire [8:0] wrapped_y_full = (sum_y >= 9'd240) ? sum_y - 9'd240 : sum_y;
    wire [8:0] wrapped_x = wrapped_x_full[8:0];
    wire [7:0] wrapped_y = wrapped_y_full[7:0];
    wire [5:0] tile_col = wrapped_x[8:3];
    wire [2:0] sub_x = wrapped_x[2:0];
    wire [4:0] tile_row = wrapped_y[7:3];
    wire [2:0] sub_y = wrapped_y[2:0];

    reg [7:0] row_cache [0:39];
    reg [4:0] cached_tile_row;
    reg cache_valid;
    reg [5:0] prefetch_idx;
    wire row_needs_refresh = !cache_valid || (tile_row != cached_tile_row);
    wire [10:0] tile_row_extended = {6'd0, tile_row};

    always @(posedge clk) begin
        if (reset) begin
            state <= S_IDLE;
            fb_we <= 1'b0;
            done <= 1'b0;
            cache_valid <= 1'b0;
            cached_tile_row <= 5'd0;
            prefetch_idx <= 6'd0;
            screen_x <= 9'd0;
            screen_y <= 8'd0;
            tile_rd_addr <= 11'd0;
            pattern_rd_addr <= 14'd0;
            palette_rd_addr <= 9'd0;
            fb_wr_x <= 9'd0;
            fb_wr_y <= 8'd0;
            fb_wr_data <= 9'd0;
        end else begin
            fb_we <= 1'b0;
            done <= 1'b0;
            case (state)
                S_IDLE: if (start) begin
                    screen_x <= 9'd0;
                    screen_y <= 8'd0;
                    // Reload even if tile RAM changed between frames.
                    cache_valid <= 1'b0;
                    state <= S_ROW_CHECK;
                end
                S_ROW_CHECK: begin
                    if (row_needs_refresh) begin
                        prefetch_idx <= 6'd0;
                        state <= S_PREFETCH_SET;
                    end else state <= S_PATTERN_SET;
                end
                S_PREFETCH_SET: begin
                    tile_rd_addr <= (tile_row_extended << 5)
                                  + (tile_row_extended << 3)
                                  + {5'd0, prefetch_idx};
                    state <= S_PREFETCH_WAIT;
                end
                S_PREFETCH_WAIT: begin
                    if (TILE_EXTRA_WAIT) state <= S_PREFETCH_WAIT2;
                    else state <= S_PREFETCH_STORE;
                end
                S_PREFETCH_WAIT2: state <= S_PREFETCH_STORE;
                S_PREFETCH_STORE: begin
                    row_cache[prefetch_idx] <= tile_rd_data;
                    if (prefetch_idx == 6'd39) begin
                        cached_tile_row <= tile_row;
                        cache_valid <= 1'b1;
                        state <= S_PATTERN_SET;
                    end else begin
                        prefetch_idx <= prefetch_idx + 6'd1;
                        state <= S_PREFETCH_SET;
                    end
                end
                S_PATTERN_SET: begin
                    pattern_rd_addr <= {row_cache[tile_col], sub_y, sub_x};
                    state <= S_PATTERN_WAIT;
                end
                // SET registers the address; WAIT lets RAM capture it;
                // WAIT2 lets RAM register q; PALETTE_SET samples q
                // on the following edge, after q has become stable.
                S_PATTERN_WAIT: state <= S_PATTERN_WAIT2;
                S_PATTERN_WAIT2: state <= S_PALETTE_SET;
                S_PALETTE_SET: begin
                    palette_rd_addr <= {1'b0, pattern_rd_data};
                    state <= S_PALETTE_WAIT;
                end
                S_PALETTE_WAIT: begin
                    if (PALETTE_EXTRA_WAIT) state <= S_PALETTE_WAIT2;
                    else state <= S_WRITE;
                end
                S_PALETTE_WAIT2: state <= S_WRITE;
                S_WRITE: begin
                    fb_we <= 1'b1;
                    fb_wr_x <= screen_x;
                    fb_wr_y <= screen_y;
                    fb_wr_data <= palette_rd_data;
                    if (screen_x == 9'd319) begin
                        screen_x <= 9'd0;
                        if (screen_y == 8'd239) state <= S_DONE;
                        else begin
                            screen_y <= screen_y + 8'd1;
                            state <= S_ROW_CHECK;
                        end
                    end else begin
                        screen_x <= screen_x + 9'd1;
                        state <= S_PATTERN_SET;
                    end
                end
                S_DONE: begin
						 done <= 1'b1;

						 state <= S_IDLE;
					end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
