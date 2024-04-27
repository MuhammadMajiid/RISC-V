module riscv_core_top#(
    parameter DATA_WIDTH = 64,
    parameter ADDR_WIDTH = 64,
    parameter CACHE_LINE_WIDTH = 256
)(
    // Global inputs
    input  wire i_riscv_core_clk,
    input  wire i_riscv_core_rst_n,
    input  wire i_riscv_core_external_interrupt_m,
    input  wire i_riscv_core_external_interrupt_s,
    output wire o_riscv_core_ack,
    ///uart
    input  wire i_uart_ready,
    output wire [7:0] o_uart_out_data,
    output wire o_uart_valid

);
    //Data_Cache
    wire [63:0] o_riscv_core_dcache_raddr_axi;
    wire [63:0] o_riscv_core_dcache_wdata;
    wire [63:0] o_riscv_core_dcache_waddr;
    wire o_riscv_core_dcache_raddr_valid;
    wire o_riscv_core_dcache_wvalid;
    wire i_riscv_core_dcache_rready;
    wire i_riscv_core_dcache_wresp;
    wire [255:0] i_riscv_core_dcache_rdata;
    wire [ 7 : 0] o_riscv_core_dcache_wstrb;

    //INSTR_CACHE
    wire [63:0] o_riscv_core_icache_raddr_axi;
    wire o_riscv_core_icache_raddr_valid;
    wire i_riscv_core_icache_rready;
    wire [255:0] i_riscv_core_icache_rdata;
    //wire o_mem_write_done_dummy;
    //wire i_mem_write_valid_dummy;
    //wire [63:0] i_mem_write_data_dummy;
    //wire [63:0] i_mem_write_address_dummy;
    //wire [7:0 ] i_write_strobe_dummy;

    //Memory translator
    wire [ADDR_WIDTH-1     : 0] o_mem_read_address;
    wire                        o_mem_read_req;
    wire                        i_mem_read_done;
    wire [CACHE_LINE_WIDTH-1 : 0] i_cache_line;
             // Interface with WRITE CHANNEL //
    wire                         i_mem_write_done;
    wire                          o_mem_write_valid;
    wire [     DATA_WIDTH-1 : 0]  o_mem_write_data;
    wire [     ADDR_WIDTH-1 : 0]  o_mem_write_address;
    wire [                7 : 0]  o_write_strobe;

riscv_core_top_2
u_riscv_core_top_2 
(
    // Global inputs
    .i_riscv_core_clk(i_riscv_core_clk)
    ,.i_riscv_core_rst_n(i_riscv_core_rst_n)
    ,.i_riscv_core_external_interrupt_m(i_riscv_core_external_interrupt_m)
    ,.i_riscv_core_external_interrupt_s(i_riscv_core_external_interrupt_s)
    ,.o_riscv_core_ack(o_riscv_core_ack)
    //Data_Cache
    ,.mem_read_address(o_riscv_core_dcache_raddr_axi)/////
    ,.o_mem_write_data(o_riscv_core_dcache_wdata)/////
    ,.o_mem_write_address(o_riscv_core_dcache_waddr)////
    ,.mem_read_req(o_riscv_core_dcache_raddr_valid)////
    ,.o_mem_write_valid(o_riscv_core_dcache_wvalid)/////
    ,.mem_read_done(i_riscv_core_dcache_rready)//////
    ,.i_mem_write_done(i_riscv_core_dcache_wresp)//////
    ,.i_block_from_axi_data_cache(i_riscv_core_dcache_rdata)//////
    ,.o_mem_write_strobe(o_riscv_core_dcache_wstrb)//////
  //INSTR_CACHE
    ,.o_addr_from_control_to_axi(o_riscv_core_icache_raddr_axi)/////
    ,.o_mem_req(o_riscv_core_icache_raddr_valid)/////
    ,.i_mem_done(i_riscv_core_icache_rready)/////
    ,.i_block_from_axi_i_cache(i_riscv_core_icache_rdata)/////
    ,.uart_ready(i_uart_ready)
    ,.uart_out_data(o_uart_out_data)
    ,.uart_valid(o_uart_valid)
);

mem_translator
u_mem_translator
(
    .i_clk(i_riscv_core_clk)
    // DATA CACHE PORT //
    ,.i_dcache_write_data(o_riscv_core_dcache_wdata)
    ,.i_dcache_write_address(o_riscv_core_dcache_waddr)
    ,.i_dcache_write_valid(o_riscv_core_dcache_wvalid)
    ,.i_dcache_write_strobe(o_riscv_core_dcache_wstrb)
    ,.i_dcache_read_req(o_riscv_core_dcache_raddr_valid)
    ,.i_dcache_read_address(o_riscv_core_dcache_raddr_axi)
    ,.o_dcache_cache_line(i_riscv_core_dcache_rdata)
    ,.o_dcache_read_done(i_riscv_core_dcache_rready)
    ,.o_dcache_write_done(i_riscv_core_dcache_wresp)
    // INST CACHE PORT //
    ,.i_icache_read_req(o_riscv_core_icache_raddr_valid)
    ,.i_icache_read_address(o_riscv_core_icache_raddr_axi)
    ,.o_icache_cache_line(i_riscv_core_icache_rdata)
    ,.o_icache_read_done(i_riscv_core_icache_rready)
    // MEMORY PORT //
    // Interface with READ CHANNEL //
    ,.o_mem_read_address(o_mem_read_address)
    ,.o_mem_read_req(o_mem_read_req)
    ,.i_mem_read_done(i_mem_read_done)
    ,.i_cache_line(i_cache_line)
    // Interface with WRITE CHANNEL //
    ,.i_mem_write_done(i_mem_write_done)
    ,.o_mem_write_valid(o_mem_write_valid)
    ,.o_mem_write_data(o_mem_write_data)
    ,.o_mem_write_address(o_mem_write_address)
    ,.o_write_strobe(o_write_strobe)
);

data_mem_top
u_main_mem_data
(
    .i_clk(i_riscv_core_clk)
    ,.i_rst_n(i_riscv_core_rst_n)
    // Interface with READ CHANNEL //
    ,.i_mem_read_address(o_mem_read_address)
    ,.i_mem_read_req(o_mem_read_req)
    ,.o_mem_read_done(i_mem_read_done)
    ,.o_cache_line(i_cache_line)
    // Interface with WRITE CHANNEL //
    ,.o_mem_write_done(i_mem_write_done)
    ,.i_mem_write_valid(o_mem_write_valid)
    ,.i_mem_write_data(o_mem_write_data)
    ,.i_mem_write_address(o_mem_write_address)
    ,.i_write_strobe(o_write_strobe)
);


/*
data_mem_top
u_instr_main_mem
(
    .i_clk(i_riscv_core_clk)
    ,.i_rst_n(i_riscv_core_rst_n)
    // Interface with READ CHANNEL //
    ,.i_mem_read_address(o_riscv_core_icache_raddr_axi)
    ,.i_mem_read_req(o_riscv_core_icache_raddr_valid)
    ,.o_mem_read_done(i_riscv_core_icache_rready)
    ,.o_cache_line(i_riscv_core_icache_rdata)
    // Interface with WRITE CHANNEL //
    ,.o_mem_write_done(o_mem_write_done_dummy)
    ,.i_mem_write_valid(i_mem_write_valid_dummy)
    ,.i_mem_write_data(i_mem_write_data_dummy)
    ,.i_mem_write_address(i_mem_write_address_dummy)
    ,.i_write_strobe(i_write_strobe_dummy)
);

assign i_mem_write_valid_dummy    = 1'b0 ;
assign i_mem_write_data_dummy     = 64'b0;
assign i_mem_write_address_dummy  = 64'b0;
assign i_write_strobe_dummy       = 8'b0 ;
*/

endmodule