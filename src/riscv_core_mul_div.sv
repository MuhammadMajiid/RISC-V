module riscv_core_mul_div 
#(
  parameter XLEN = 64
)
(
  input   logic [XLEN-1:0] i_mul_div_srcA,
  input   logic [XLEN-1:0] i_mul_div_srcB,
  input   logic [4:0]      i_mul_div_control,
  input   logic            i_mul_div_isword,
  input   logic            i_mul_div_clk,
  input   logic            i_mul_div_rstn,   
  output  logic            o_mul_div_done,
  output  logic [XLEN-1:0] o_mul_div_result 
);

riscv_core_mul
#(
  .XLEN(XLEN)
)
(
  .i_mul_srcA(i_mul_div_srcA),
  .i_mul_srcB(i_mul_div_srcB),
  .i_mul_control(i_mul_div_control[1:0]),
  .i_mul_isword(i_mul_div_isword),
  .i_mul_en(!i_mul_div_control[2] & i_mul_div_control[4]),
  .o_mul_result(o_mul_div_result)
);

riscv_core_div
#(
  .XLEN(XLEN)
)
u_riscv_core_div
(
  i_div_srcA(i_mul_div_srcA),
  i_div_srcB(i_mul_div_srcB),
  i_div_control(i_mul_div_control[1:0]),
  i_div_isword(i_mul_div_isword),
  i_div_en(i_mul_div_control[2] & i_mul_div_control[4]),
  i_div_clk(i_mul_div_clk),
  i_div_rstn(i_mul_div_rstn),
  o_div_done(o_mul_div_done),
  o_div_result(o_mul_div_result)
);
endmodule