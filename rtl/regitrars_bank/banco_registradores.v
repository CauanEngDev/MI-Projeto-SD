module banco_registradores (
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] instrucao,
    input  wire        write_enable,
    input  wire [31:0] write_data,

    output wire [31:0] read_data_a,
    output wire [31:0] read_data_b,
    output wire [31:0] cpsr,
    output wire [31:0] spsr,
    output wire [31:0] gpustat,
    output wire [31:0] gpuerr
);

    reg [31:0] registradores [0:31];

    reg [31:0] reg_cpsr;
    reg [31:0] reg_spsr;
    reg [31:0] reg_gpustat;
    reg [31:0] reg_gpuerr;

    wire [4:0] campo_rd;
    wire [4:0] campo_ra;
    wire [4:0] campo_rb;

    assign campo_rd = instrucao[23:19];
    assign campo_ra = instrucao[18:14];
    assign campo_rb = instrucao[13:9];

    assign read_data_a = registradores[campo_ra];
    assign read_data_b = registradores[campo_rb];

    assign cpsr    = reg_cpsr;
    assign spsr    = reg_spsr;
    assign gpustat = reg_gpustat;
    assign gpuerr  = reg_gpuerr;

    always @(posedge clk) begin
        if (reset) begin
            registradores[0]  <= 32'b0;
            registradores[1]  <= 32'b0;
            registradores[2]  <= 32'b0;
            registradores[3]  <= 32'b0;
            registradores[4]  <= 32'b0;
            registradores[5]  <= 32'b0;
            registradores[6]  <= 32'b0;
            registradores[7]  <= 32'b0;
            registradores[8]  <= 32'b0;
            registradores[9]  <= 32'b0;
            registradores[10] <= 32'b0;
            registradores[11] <= 32'b0;
            registradores[12] <= 32'b0;
            registradores[13] <= 32'b0;
            registradores[14] <= 32'b0;
            registradores[15] <= 32'b0;
            registradores[16] <= 32'b0;
            registradores[17] <= 32'b0;
            registradores[18] <= 32'b0;
            registradores[19] <= 32'b0;
            registradores[20] <= 32'b0;
            registradores[21] <= 32'b0;
            registradores[22] <= 32'b0;
            registradores[23] <= 32'b0;
            registradores[24] <= 32'b0;
            registradores[25] <= 32'b0;
            registradores[26] <= 32'b0;
            registradores[27] <= 32'b0;
            registradores[28] <= 32'b0;
            registradores[29] <= 32'b0;
            registradores[30] <= 32'b0;
            registradores[31] <= 32'b0;

            reg_cpsr    <= 32'b0;
            reg_spsr    <= 32'b0;
            reg_gpustat <= 32'b0;
            reg_gpuerr  <= 32'b0;
        end
        else begin
            if (write_enable) begin
                registradores[campo_rd] <= write_data;
            end
        end
    end

endmodule
