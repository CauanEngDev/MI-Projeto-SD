`ifndef ISA_VH
`define ISA_VH

`define NOP  5'b00000
`define ADD  5'b00001
`define SUB  5'b00010
`define AND  5'b00011
`define LSL  5'b00100
`define LSR  5'b00101
`define PASS 5'b00110
`define SEP  5'b00111
`define DRR  5'b01000
`define DRT  5'b01001
`define SESP 5'b01010
`define SESA 5'b01011
`define SETM 5'b01100
`define SCB  5'b01101
`define WRSD 5'b01110
`define WRTD 5'b01111
`define CLF  5'b10000
`define DRB  5'b10001
`define DRS  5'b10010
`define SWB  5'b10011
`define WVB  5'b10100
`define HALT 5'b10101

`endif