module riscv_core_top 
//-------------Global Parameters-------------//
#
(
  parameter BLOCK_OFFSET       = 2,
  parameter BLOCK_OFFSET_WIDTH = 2,
  parameter INDEX_WIDTH        = 7,
  parameter I_TAG_WIDTH        = 20,
  parameter I_CORE_DATA_WIDTH  = 32,
  parameter ADDR_WIDTH         = 64,
  parameter AXI_DATA_WIDTH     = 64,
  parameter D_TAG_WIDTH        = 52,
  parameter D_CORE_DATA_WIDTH  = 64,
  parameter STRB_WIDTH         = 8
)
(
  // Global inputs
  input wire i_riscv_core_clk,
  input wire i_riscv_core_rst_n,

  // Instruction Cache - AXI Interface with DDR - Read Channel
  output wire [ADDR_WIDTH-1:0]          o_riscv_core_icache_raddr_axi,   // addr to mem
  output wire                           o_riscv_core_icache_raddr_valid, // mem req
  input  wire                           i_riscv_core_icache_rready,
  input  wire [AXI_DATA_WIDTH-1:0]      i_riscv_core_icache_rdata, 

  // Data Cache - AXI Interface with DDR - Read Channel
  output wire [ADDR_WIDTH-1:0]          o_riscv_core_dcache_raddr_axi,
  output wire                           o_riscv_core_dcache_raddr_valid,
  input  wire                           i_riscv_core_dcache_rready,
  input  wire [AXI_DATA_WIDTH-1:0]      i_riscv_core_dcache_rdata,

  // Data Cache - AXI Interface with DDR - Write Channel
  input  wire                           i_riscv_core_dcache_wresp,
  output wire                           o_riscv_core_dcache_wvalid,
  output wire [D_CORE_DATA_WIDTH-1:0]   o_riscv_core_dcache_wdata,
  output wire [ADDR_WIDTH-1:0]          o_riscv_core_dcache_waddr,
  output wire [STRB_WIDTH-1:0]          o_riscv_core_dcache_wstrb
);
//-------------Local Parameters-------------//

//-------------IF Intermediate Signals-------------//
wire [63:0] if_id_pipe_pc;
wire [63:0] if_id_pipe_pcf_new;
wire [63:0] compressed_offset;
wire [63:0] if_id_pipe_pc_plus_offset;
wire [31:0] if_id_pipe_instr;
wire [63:0] pcf;
wire [63:0] pc_plus_offset_if;
wire [63:0] mux_to_stg2;
wire [31:0] instr;
wire [31:0] c_ext_instr_out;
wire        instr_is_compressed;
wire        instr_is_illegal;

//-------------ID Intermediate Signals-------------//
wire [63:0] id_ex_pipe_imm;
wire [63:0] id_ex_pipe_rd1;
wire [63:0] id_ex_pipe_rd2;
wire [63:0] id_ex_pipe_pc;
wire [63:0] id_ex_pipe_pc_plus_offset;
wire [4:0]  id_ex_pipe_rd;
wire [4:0]  id_ex_pipe_rs1;
wire [4:0]  id_ex_pipe_rs2;
wire [3:0]  id_ex_pipe_alu_control;
wire [2:0]  id_ex_pipe_funct3;
wire [1:0]  id_ex_pipe_resultsrc;
wire [1:0]  id_ex_pipe_size;
wire        id_ex_pipe_alu_srcb;
wire        id_ex_pipe_branch;
wire        id_ex_pipe_isword;
wire        id_ex_pipe_jump;
wire        id_ex_pipe_ldext;
wire        id_ex_pipe_uctrl;
wire        id_ex_pipe_memwrite;
wire        id_ex_pipe_regwrite;
wire [63:0] rd1_id;
wire [63:0] rd2_id;
wire [63:0] immext_id;
wire [3:0]  alu_control_id;
wire [2:0]  immsrc_id;
wire [1:0]  resultsrc_id;
wire [1:0]  size_id;
wire        alu_op_id;
wire        uctrl_id;
wire        regwrite_id;
wire        alusrc_id;
wire        memwrite_id;
wire        branch_id;
wire        jump_id;
wire        ldext_id;
wire        isword_id;
wire        bjreg_id;
wire        id_ex_pipe_bjreg;
wire        im_sel_id;
wire        id_ex_pipe_im_sel;

//-------------EX Intermediate Signals-------------//
wire [63:0] ex_mem_pipe_alu_result;
wire [63:0] ex_mem_pipe_wd;
wire [63:0] ex_mem_pipe_auipc;
wire [63:0] ex_mem_pipe_pc_plus_offset;
wire [4:0]  ex_mem_pipe_rd;
wire [1:0]  ex_mem_pipe_resultsrc;
wire [1:0]  ex_mem_pipe_size;
wire        ex_mem_pipe_memwrite;
wire        ex_mem_pipe_ldext;
wire        ex_mem_pipe_regwrite;
wire [63:0] src_a_ex;
wire [63:0] src_b_ex;
wire [63:0] src_b_out;
wire [63:0] alu_result_ex;
wire [63:0] m_ext_res;
wire [63:0] arith_result_ex;
wire [63:0] pc_plus_imm;
wire [63:0] auipc;
wire        istaken_ex;
wire        pcsrc_ex;
wire        m_ext_done;
wire        m_ext_busy;
wire        m_ext_divby0;
wire        m_ext_of;

//-------------MEM Intermediate Signals------------//
wire [63:0] read_data_mem;
wire [63:0] mem_wb_pipe_alu_result;
wire [63:0] mem_wb_pipe_read_data;
wire [63:0] mem_wb_pipe_auipc;
wire [63:0] mem_wb_pipe_pc_plus_offset;
wire [4:0]  mem_wb_pipe_rd;
wire [1:0]  mem_wb_pipe_resultsrc;
wire        mem_wb_pipe_regwrite; 

//-------------WB Intermediate Signals-------------//
wire [63:0] result_wb;

//-------------HU Intermediate Signals-------------//
wire [1:0]  hu_forward_a;
wire [1:0]  hu_forward_b;
wire        hu_stall_if;
wire        hu_stall_id;
wire        hu_stall_ex;
wire        hu_stall_mem;
wire        hu_stall_wb;
wire        hu_flush_id;
wire        hu_flush_ex;
wire        hu_exception;

//-------------ICache Intermediate Signals-------------//
wire                      icache_hu_stall;

//-------------DCache Intermediate Signals-------------//
wire [1:0]                   size;
wire                         write;
wire                         read;
wire                         store_fault;
wire                         load_fault;
wire                         dcache_hu_stall;
wire [D_CORE_DATA_WIDTH-1:0] dcache_data;

//----------------------------------//
//-------------IF Stage-------------//
//----------------------------------//

riscv_core_mux2x1
#(
  .XLEN (64)
)
u_riscv_core_mux2x1_stg1
(
  .i_mux2x1_in0 (auipc)
  ,.i_mux2x1_in1(alu_result_ex)
  ,.i_mux2x1_sel(id_ex_pipe_bjreg)
  ,.o_mux2x1_out(mux_to_stg2)
);

riscv_core_mux2x1
#(
  .XLEN (64)
)
u_riscv_core_mux2x1_stg2
(
  .i_mux2x1_in0 (pc_plus_offset_if)
  ,.i_mux2x1_in1(mux_to_stg2)
  ,.i_mux2x1_sel(pcsrc_ex)
  ,.o_mux2x1_out(pcf)
);

riscv_core_mux2x1
#(
  .XLEN (64)
)
u_riscv_core_compressed_offset
(
  .i_mux2x1_in0 (64'd4)
  ,.i_mux2x1_in1(64'd2)
  ,.i_mux2x1_sel(instr_is_compressed)
  ,.o_mux2x1_out(compressed_offset)
);

riscv_core_64bit_adder
#(
  .XLEN (64)
)
u_riscv_core_64bit_adder_pc_if
(
  .i_64bit_adder_srcA   (if_id_pipe_pcf_new)
  ,.i_64bit_adder_srcB  (compressed_offset)
  ,.o_64bit_adder_result(pc_plus_offset_if)
);

// Replaced by I chache
// riscv_core_imem
// #(
//   .ALEN (64)
//   ,.ILEN(32)
//   ,.MWID(8)
//   ,.MLEN(5000)
// )
// u_riscv_core_imem
// (
//   .i_imem_rst_n    (i_riscv_core_rst_n)
//   ,.i_imem_address (if_id_pipe_pcf_new)
//   ,.o_imem_rdata   (instr)
// );

// riscv_core_axi4lite
// #
// (
//   .ADDR_WIDTH     ()
//   ,.AXI_DATA_WIDTH()
//   ,.STRB_WIDTH    ()
// )
// riscv_core_axi4lite_icache
// (
//   .axi_clk      ()
//   ,.axi_arstn   ()
//   ,.saxi_araddr ()
//   ,.saxi_arprot ()
//   ,.saxi_arvalid()
//   ,.saxi_arready()
//   ,.saxi_rdata  ()
//   ,.saxi_rresp  ()
//   ,.saxi_rvalid ()
//   ,.saxi_rready ()
//   ,.maxi_araddr ()
//   ,.maxi_arprot ()
//   ,.maxi_arvalid()
//   ,.maxi_arready()
//   ,.maxi_rdata  ()
//   ,.maxi_rresp  ()
//   ,.maxi_rvalid ()
//   ,.maxi_rready ()
// );

riscv_core_icache_top
#(
  .BLOCK_OFFSET_WIDTH(BLOCK_OFFSET_WIDTH)
  ,.INDEX_WIDTH      (INDEX_WIDTH)
  ,.TAG_WIDTH        (I_TAG_WIDTH)
  ,.CORE_DATA_WIDTH  (I_CORE_DATA_WIDTH)
  ,.ADDR_WIDTH       (ADDR_WIDTH)
  ,.AXI_DATA_WIDTH   (AXI_DATA_WIDTH)
)
u_riscv_core_icache
(
  .i_clk                      (i_riscv_core_clk)
  ,.i_rst_n                   (i_riscv_core_rst_n)
  ,.i_addr_from_core          (if_id_pipe_pcf_new)
  ,.o_stall                   (icache_hu_stall)
  ,.o_data_to_core            (instr)
  ,.o_addr_from_control_to_axi(o_riscv_core_icache_raddr_axi)
  ,.o_mem_req                 (o_riscv_core_icache_raddr_valid)
  ,.i_mem_done                (i_riscv_core_icache_rready)
  ,.i_block_from_axi          (i_riscv_core_icache_rdata)
);

riscv_core_compressed_decoder
u_riscv_core_compressed_decoder
(
  .i_compressed_decoder_instr         (instr)
  ,.o_compressed_decoder_instr        (c_ext_instr_out)
  ,.o_compressed_decoder_is_compressed(instr_is_compressed)
  ,.o_compressed_decoder_illegal_instr(instr_is_illegal)    // flag for illegal instr handling
);

//----------------------------------//
//------------IF/ID Pipe------------//
//----------------------------------//

riscv_core_pipe 
#(
  .W_PIPE_BUS (64)
)
u_riscv_core_pipe_pcf_if
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (1'b0)
  ,.i_pipe_en_n  (hu_stall_if)
  ,.i_pipe_in    (pcf)
  ,.o_pipe_out   (if_id_pipe_pcf_new)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (64)
)
u_riscv_core_pipe_pc_if_id
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (hu_flush_id)
  ,.i_pipe_en_n  (hu_stall_id)
  ,.i_pipe_in    (if_id_pipe_pcf_new)
  ,.o_pipe_out   (if_id_pipe_pc)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (32)
)
u_riscv_core_pipe_instr_if_id
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (hu_flush_id)
  ,.i_pipe_en_n  (hu_stall_id)
  ,.i_pipe_in    (c_ext_instr_out)  // output of compressed decoder
  ,.o_pipe_out   (if_id_pipe_instr)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (64)
)
u_riscv_core_pipe_pc_plus_offset_if_id
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (hu_flush_id)
  ,.i_pipe_en_n  (hu_stall_id)
  ,.i_pipe_in    (pc_plus_offset_if)
  ,.o_pipe_out   (if_id_pipe_pc_plus_offset)
);

//----------------------------------//
//-------------ID Stage-------------//
//----------------------------------//

riscv_core_alu_decoder 
u_riscv_core_alu_decoder
(
  .i_alu_decoder_funct3     (if_id_pipe_instr[14:12])
  ,.i_alu_decoder_aluop     (alu_op_id)
  ,.i_alu_decoder_funct7_5  (if_id_pipe_instr[30])
  ,.i_alu_decoder_opcode_5  (if_id_pipe_instr[5])
  ,.i_alu_decoder_funct7_0  ()                                   // Unconnected
  ,.o_alu_decoder_alucontrol(alu_control_id)
);

riscv_core_main_decoder
u_riscv_core_main_decoder
(
  .i_main_decoder_opcode     (if_id_pipe_instr[6:0])
  ,.i_main_decoder_funct3    (if_id_pipe_instr[14:12])
  ,.i_main_decoder_funct7    (if_id_pipe_instr[31:25])
  ,.o_main_decoder_imsrc     (immsrc_id)
  ,.o_main_decoder_UCtrl     (uctrl_id)
  ,.o_main_decoder_resultsrc (resultsrc_id)
  ,.o_main_decoder_regwrite  (regwrite_id)
  ,.o_main_decoder_alusrcB   (alusrc_id)
  ,.o_main_decoder_memwrite  (memwrite_id)
  ,.o_main_decoder_branch    (branch_id)
  ,.o_main_decoder_jump      (jump_id)
  ,.o_main_decoder_size      (size_id)
  ,.o_main_decoder_LdExt     (ldext_id)
  ,.o_main_decoder_isword    (isword_id)
  ,.o_main_decoder_bjreg     (bjreg_id)
  ,.o_main_decoder_aluop     (alu_op_id)
  ,.o_main_decoder_imsel     (im_sel_id)
  ,.o_main_decoder_new_mux_sel ()                            // Unconnected
);

riscv_core_rf
u_riscv_core_rf
(
	.i_rf_clk	 (i_riscv_core_clk)
	,.i_rf_we3 (mem_wb_pipe_regwrite)
	,.i_rf_a1  (if_id_pipe_instr[19:15])
	,.i_rf_a2  (if_id_pipe_instr[24:20])
	,.i_rf_a3  (mem_wb_pipe_rd)
	,.i_rf_wd3 (result_wb)
	,.o_rf_rd1 (rd1_id)
	,.o_rf_rd2 (rd2_id)
);


riscv_core_immextend
u_riscv_core_immextend
(
  .i_immextend_imm     (if_id_pipe_instr[31:7]) //instruction [31:7]
  ,.i_immextend_immsrc (immsrc_id)              //cotrol from MAin decoder
  ,.o_immextend_out    (immext_id)              //extended output
);

//----------------------------------//
//------------ID/EX Pipe------------//
//----------------------------------//


//-----------Data Signals-----------//
riscv_core_pipe 
#(
  .W_PIPE_BUS (64)
)
u_riscv_core_pipe_rf_rd1_id_ex
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (hu_flush_ex)
  ,.i_pipe_en_n  (hu_stall_ex)
  ,.i_pipe_in    (rd1_id)
  ,.o_pipe_out   (id_ex_pipe_rd1)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (64)
)
u_riscv_core_pipe_rf_rd2_id_ex
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (hu_flush_ex)
  ,.i_pipe_en_n  (hu_stall_ex)
  ,.i_pipe_in    (rd2_id)
  ,.o_pipe_out   (id_ex_pipe_rd2)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (3)
)
u_riscv_core_pipe_funct3_id_ex
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (hu_flush_ex)
  ,.i_pipe_en_n  (hu_stall_ex)
  ,.i_pipe_in    (if_id_pipe_instr[14:12]) // funct3
  ,.o_pipe_out   (id_ex_pipe_funct3)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (64)
)
u_riscv_core_pipe_pc_id_ex
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (hu_flush_ex)
  ,.i_pipe_en_n  (hu_stall_ex)
  ,.i_pipe_in    (if_id_pipe_pc)
  ,.o_pipe_out   (id_ex_pipe_pc)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (5)
)
u_riscv_core_pipe_rs1_id_ex
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (hu_flush_ex)
  ,.i_pipe_en_n  (hu_stall_ex)
  ,.i_pipe_in    (if_id_pipe_instr[19:15]) // rs1D
  ,.o_pipe_out   (id_ex_pipe_rs1)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (5)
)
u_riscv_core_pipe_rs2_id_ex
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (hu_flush_ex)
  ,.i_pipe_en_n  (hu_stall_ex)
  ,.i_pipe_in    (if_id_pipe_instr[24:20]) // rs2D
  ,.o_pipe_out   (id_ex_pipe_rs2)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (5)
)
u_riscv_core_pipe_rd_id_ex
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (hu_flush_ex)
  ,.i_pipe_en_n  (hu_stall_ex)
  ,.i_pipe_in    (if_id_pipe_instr[11:7]) // rdD
  ,.o_pipe_out   (id_ex_pipe_rd)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (64)
)
u_riscv_core_pipe_pc_plus_offset_id_ex
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (hu_flush_ex)
  ,.i_pipe_en_n  (hu_stall_ex)
  ,.i_pipe_in    (if_id_pipe_pc_plus_offset) // (pc+4)D
  ,.o_pipe_out   (id_ex_pipe_pc_plus_offset)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (64)
)
u_riscv_core_pipe_immext_id_ex
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (hu_flush_ex)
  ,.i_pipe_en_n  (hu_stall_ex)
  ,.i_pipe_in    (immext_id)
  ,.o_pipe_out   (id_ex_pipe_imm)
);

//---------Control Signals----------//
riscv_core_pipe 
#(
  .W_PIPE_BUS (2)
)
u_riscv_core_pipe_resultsrc_id_ex
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (hu_flush_ex)
  ,.i_pipe_en_n  (hu_stall_ex)
  ,.i_pipe_in    (resultsrc_id)
  ,.o_pipe_out   (id_ex_pipe_resultsrc)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (2)
)
u_riscv_core_pipe_size_id_ex
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (hu_flush_ex)
  ,.i_pipe_en_n  (hu_stall_ex)
  ,.i_pipe_in    (size_id)
  ,.o_pipe_out   (id_ex_pipe_size)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (4)
)
u_riscv_core_pipe_alucontrol_id_ex
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (hu_flush_ex)
  ,.i_pipe_en_n  (hu_stall_ex)
  ,.i_pipe_in    (alu_control_id)
  ,.o_pipe_out   (id_ex_pipe_alu_control)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (1)
)
u_riscv_core_pipe_bjreg_id_ex
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (hu_flush_ex)
  ,.i_pipe_en_n  (hu_stall_ex)
  ,.i_pipe_in    (bjreg_id)
  ,.o_pipe_out   (id_ex_pipe_bjreg)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (1)
)
u_riscv_core_pipe_regwrite_id_ex
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (hu_flush_ex)
  ,.i_pipe_en_n  (hu_stall_ex)
  ,.i_pipe_in    (regwrite_id)
  ,.o_pipe_out   (id_ex_pipe_regwrite)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (1)
)
u_riscv_core_pipe_branch_id_ex
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (hu_flush_ex)
  ,.i_pipe_en_n  (hu_stall_ex)
  ,.i_pipe_in    (branch_id)
  ,.o_pipe_out   (id_ex_pipe_branch)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (1)
)
u_riscv_core_pipe_jump_id_ex
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (hu_flush_ex)
  ,.i_pipe_en_n  (hu_stall_ex)
  ,.i_pipe_in    (jump_id)
  ,.o_pipe_out   (id_ex_pipe_jump)
);


riscv_core_pipe 
#(
  .W_PIPE_BUS (1)
)
u_riscv_core_pipe_memwrite_id_ex
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (hu_flush_ex)
  ,.i_pipe_en_n  (hu_stall_ex)
  ,.i_pipe_in    (memwrite_id)
  ,.o_pipe_out   (id_ex_pipe_memwrite)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (1)
)
u_riscv_core_pipe_alusrc_id_ex
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (hu_flush_ex)
  ,.i_pipe_en_n  (hu_stall_ex)
  ,.i_pipe_in    (alusrc_id)
  ,.o_pipe_out   (id_ex_pipe_alu_srcb)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (1)
)
u_riscv_core_pipe_ldext_id_ex
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (hu_flush_ex)
  ,.i_pipe_en_n  (hu_stall_ex)
  ,.i_pipe_in    (ldext_id)
  ,.o_pipe_out   (id_ex_pipe_ldext)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (1)
)
u_riscv_core_pipe_uctrl_id_ex
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (hu_flush_ex)
  ,.i_pipe_en_n  (hu_stall_ex)
  ,.i_pipe_in    (uctrl_id)
  ,.o_pipe_out   (id_ex_pipe_uctrl)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (1)
)
u_riscv_core_pipe_isword_id_ex
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (hu_flush_ex)
  ,.i_pipe_en_n  (hu_stall_ex)
  ,.i_pipe_in    (isword_id)
  ,.o_pipe_out   (id_ex_pipe_isword)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (1)
)
u_riscv_core_pipe_imul_id_ex
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (hu_flush_ex)
  ,.i_pipe_en_n  (hu_stall_ex)
  ,.i_pipe_in    (im_sel_id)
  ,.o_pipe_out   (id_ex_pipe_im_sel)
);

//----------------------------------//
//-------------EX Stage-------------//
//----------------------------------//

riscv_core_mux3x1
#(
  .XLEN (64)
)
u_riscv_core_mux3x1_srca
(
  .i_mux3x1_in0 (id_ex_pipe_rd1)
  ,.i_mux3x1_in1(result_wb)
  ,.i_mux3x1_in2(ex_mem_pipe_alu_result)
  ,.i_mux3x1_sel(hu_forward_a)
  ,.o_mux3x1_out(src_a_ex)
);

riscv_core_mux3x1
#(
  .XLEN (64)
)
u_riscv_core_mux3x1_srcb
(
  .i_mux3x1_in0 (id_ex_pipe_rd2)
  ,.i_mux3x1_in1(result_wb)
  ,.i_mux3x1_in2(ex_mem_pipe_alu_result)
  ,.i_mux3x1_sel(hu_forward_b)
  ,.o_mux3x1_out(src_b_out)
);

riscv_core_mux2x1
#(
  .XLEN (64)
)
u_riscv_core_mux2x1_srcb
(
  .i_mux2x1_in0 (src_b_out)
  ,.i_mux2x1_in1(id_ex_pipe_imm)
  ,.i_mux2x1_sel(id_ex_pipe_alu_srcb)
  ,.o_mux2x1_out(src_b_ex)
);

riscv_core_alu
#(
  .XLEN (64)
)
u_riscv_core_alu
(
  .i_alu_srcA    (src_a_ex)
  ,.i_alu_srcB   (src_b_ex)
  ,.i_alu_control(id_ex_pipe_alu_control)
  ,.i_alu_isword (id_ex_pipe_isword)
  ,.o_alu_result (alu_result_ex)
);

riscv_core_mul_div
#(
  .XLEN(64)
)
u_riscv_core_mul_div
(
  .i_mul_div_clk         (i_riscv_core_clk)
  ,.i_mul_div_rstn       (i_riscv_core_rst_n)
  ,.i_mul_div_srcA       (src_a_ex)
  ,.i_mul_div_srcB       (src_b_out)
  ,.i_mul_div_control    (id_ex_pipe_alu_control)
  ,.i_mul_div_isword     (id_ex_pipe_isword)
  ,.i_mul_div_en         (id_ex_pipe_im_sel) // is_MulE
  ,.o_mul_div_result     (m_ext_res)
  ,.o_mul_div_busy       (m_ext_busy)
  ,.o_mul_div_done       (m_ext_done)
  ,.o_mul_div_overflow   (m_ext_of)
  ,.o_mul_div_div_by_zero(m_ext_divby0)
);

riscv_core_mux2x1
#(
  .XLEN (64)
)
u_riscv_core_mux2x1_arith_out
(
  .i_mux2x1_in0 (alu_result_ex) 
  ,.i_mux2x1_in1(m_ext_res)// M out
  ,.i_mux2x1_sel(id_ex_pipe_im_sel) // is_mulE
  ,.o_mux2x1_out(arith_result_ex) 
);

riscv_core_branch_unit
#(
  .XLEN (64)
)
u_riscv_core_branch_unit
(
  .i_branch_unit_srcA    (src_a_ex)
  ,.i_branch_unit_srcB   (src_b_out)
  ,.i_branch_unit_funct3 (id_ex_pipe_funct3)
  ,.o_branch_unit_istaken(istaken_ex)
);

riscv_core_pcsrc 
u_riscv_core_pcsrc
(
  .i_pcsrc_istaken   (istaken_ex)
  ,.i_pcsrc_branch_ex(id_ex_pipe_branch)
  ,.i_pcsrc_jump_ex  (id_ex_pipe_jump)
  ,.o_pcsrc_pcsrc_ex (pcsrc_ex)
);

riscv_core_64bit_adder
#(
  .XLEN (64)
)
u_riscv_core_64bit_adder_target_pc_ex
(
  .i_64bit_adder_srcA   (id_ex_pipe_pc)
  ,.i_64bit_adder_srcB  (id_ex_pipe_imm)
  ,.o_64bit_adder_result(pc_plus_imm)
);

riscv_core_mux2x1
#(
  .XLEN (64)
)
u_riscv_core_mux2x1_imm
(
  .i_mux2x1_in0 (pc_plus_imm)
  ,.i_mux2x1_in1(id_ex_pipe_imm)
  ,.i_mux2x1_sel(id_ex_pipe_uctrl)
  ,.o_mux2x1_out(auipc)
);

//----------------------------------//
//-----------EX/MEM Pipe------------//
//----------------------------------//

//-----------Data Signals-----------//
riscv_core_pipe 
#(
  .W_PIPE_BUS (64)
)
u_riscv_core_pipe_alu_result_ex_mem
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (1'b0)
  ,.i_pipe_en_n  (hu_hazard_mem)
  ,.i_pipe_in    (arith_result_ex)
  ,.o_pipe_out   (ex_mem_pipe_alu_result)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (64)
)
u_riscv_core_pipe_wd_ex_mem
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (1'b0)
  ,.i_pipe_en_n  (hu_hazard_mem)
  ,.i_pipe_in    (src_b_out)
  ,.o_pipe_out   (ex_mem_pipe_wd)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (64)
)
u_riscv_core_pipe_auipc_ex_mem
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (1'b0)
  ,.i_pipe_en_n  (hu_hazard_mem)
  ,.i_pipe_in    (auipc)
  ,.o_pipe_out   (ex_mem_pipe_auipc)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (5)
)
u_riscv_core_pipe_rd_ex_mem
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (1'b0)
  ,.i_pipe_en_n  (hu_hazard_mem)
  ,.i_pipe_in    (id_ex_pipe_rd)
  ,.o_pipe_out   (ex_mem_pipe_rd)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (64)
)
u_riscv_core_pipe_pc_ex_mem
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (1'b0)
  ,.i_pipe_en_n  (hu_hazard_mem)
  ,.i_pipe_in    (id_ex_pipe_pc_plus_offset)
  ,.o_pipe_out   (ex_mem_pipe_pc_plus_offset)
);

//---------Control Signals----------//
riscv_core_pipe 
#(
  .W_PIPE_BUS (2)
)
u_riscv_core_pipe_resultsrc_ex_mem
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (1'b0)
  ,.i_pipe_en_n  (hu_hazard_mem)
  ,.i_pipe_in    (id_ex_pipe_resultsrc)
  ,.o_pipe_out   (ex_mem_pipe_resultsrc)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (1)
)
u_riscv_core_pipe_memwrite_ex_mem
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (1'b0)
  ,.i_pipe_en_n  (hu_hazard_mem)
  ,.i_pipe_in    (id_ex_pipe_memwrite)
  ,.o_pipe_out   (ex_mem_pipe_memwrite)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (2)
)
u_riscv_core_pipe_size_ex_mem
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (1'b0)
  ,.i_pipe_en_n  (hu_hazard_mem)
  ,.i_pipe_in    (id_ex_pipe_size)
  ,.o_pipe_out   (ex_mem_pipe_size)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (1)
)
u_riscv_core_pipe_ldext_ex_mem
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (1'b0)
  ,.i_pipe_en_n  (hu_hazard_mem)
  ,.i_pipe_in    (id_ex_pipe_ldext)
  ,.o_pipe_out   (ex_mem_pipe_ldext)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (1)
)
u_riscv_core_pipe_regwrite_ex_mem
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (1'b0)
  ,.i_pipe_en_n  (hu_hazard_mem)
  ,.i_pipe_in    (id_ex_pipe_regwrite)
  ,.o_pipe_out   (ex_mem_pipe_regwrite)
);

//----------------------------------//
//-------------MEM Stage------------//
//----------------------------------//
// riscv_core_data_mem
// #(
//   .XLEN (64)
//   ,.MWID(8)
//   ,.MLEN(5000)
// )
// u_riscv_core_data_mem
// (
//   .i_data_mem_clk          (i_riscv_core_clk)
//   ,.i_data_mem_rst_n       (i_riscv_core_rst_n)
//   ,.i_data_mem_w_en        (ex_mem_pipe_memwrite)
//   ,.i_data_mem_ld_extend   (ex_mem_pipe_ldext)
//   ,.i_data_mem_r_w_size    (ex_mem_pipe_size)
//   ,.i_data_mem_address     (ex_mem_pipe_alu_result)
//   ,.i_data_mem_wdata       (ex_mem_pipe_wd)
//   ,.o_data_mem_rdata       (read_data_mem)
// );

riscv_core_dcache_top
#(
  .BLOCK_OFFSET(BLOCK_OFFSET)
  ,.INDEX_WIDTH      (INDEX_WIDTH)
  ,.TAG_WIDTH      (D_TAG_WIDTH)
  ,.CORE_DATA_WIDTH(D_CORE_DATA_WIDTH)
  ,.ADDR_WIDTH       (ADDR_WIDTH)
  ,.AXI_DATA_WIDTH   (AXI_DATA_WIDTH)
)
u_riscv_core_dcache
(
  .i_clk                      (i_riscv_core_clk)
  ,.i_rst_n                   (i_riscv_core_rst_n)
  ,.i_addr_from_core          (dcache_addr_from_core)
  ,.i_data_from_core          (dcache_data_from_core)
  ,.i_read                    (read)
  ,.i_write                   (write)
  ,.i_size                    (size)
  ,.o_stall                   (dcache_hu_stall)
  ,.o_store_fault             (store_fault)                                // unconnected
  ,.o_load_fault              (load_fault)                                // unconnected
  ,.o_data_to_core            (dcache_data)
  ,.o_mem_read_address        (o_riscv_core_dcache_raddr_axi)
  ,.i_mem_read_done           (i_riscv_core_dcache_rready)
  ,.o_mem_read_req            (o_riscv_core_dcache_raddr_valid)
  ,.i_block_from_axi          (i_riscv_core_dcache_rdata)
  ,.i_mem_write_done          (i_riscv_core_dcache_wresp)
  ,.o_mem_write_valid         (o_riscv_core_dcache_wvalid)
  ,.o_mem_write_data          (o_riscv_core_dcache_wdata)
  ,.o_mem_write_address       (o_riscv_core_dcache_waddr)
  ,.o_mem_write_strobe        (o_riscv_core_dcache_wstrb)
);

//----------------------------------//
//-----------MEM/WB Pipe------------//
//----------------------------------//

//-----------Data Signals-----------//

riscv_core_pipe 
#(
  .W_PIPE_BUS (64)
)
u_riscv_core_pipe_alu_result_mem_wb
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (1'b0)
  ,.i_pipe_en_n  (hu_hazard_wb)
  ,.i_pipe_in    (ex_mem_pipe_alu_result)
  ,.o_pipe_out   (mem_wb_pipe_alu_result)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (64)
)
u_riscv_core_pipe_read_data_mem_wb
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (1'b0)
  ,.i_pipe_en_n  (hu_hazard_wb)
  ,.i_pipe_in    (read_data_mem)
  ,.o_pipe_out   (mem_wb_pipe_read_data)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (64)
)
u_riscv_core_pipe_auipc_mem_wb
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (1'b0)
  ,.i_pipe_en_n  (hu_hazard_wb)
  ,.i_pipe_in    (ex_mem_pipe_auipc)
  ,.o_pipe_out   (mem_wb_pipe_auipc)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (64)
)
u_riscv_core_pipe_pc_mem_wb
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (1'b0)
  ,.i_pipe_en_n  (hu_hazard_wb)
  ,.i_pipe_in    (ex_mem_pipe_pc_plus_offset)
  ,.o_pipe_out   (mem_wb_pipe_pc_plus_offset)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (5)
)
u_riscv_core_pipe_rd_mem_wb
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (1'b0)
  ,.i_pipe_en_n  (hu_hazard_wb)
  ,.i_pipe_in    (ex_mem_pipe_rd)
  ,.o_pipe_out   (mem_wb_pipe_rd)
);

//---------Control Signals----------//
riscv_core_pipe 
#(
  .W_PIPE_BUS (2)
)
u_riscv_core_pipe_resultsrc_mem_wb
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (1'b0)
  ,.i_pipe_en_n  (hu_hazard_wb)
  ,.i_pipe_in    (ex_mem_pipe_resultsrc)
  ,.o_pipe_out   (mem_wb_pipe_resultsrc)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (1)
)
u_riscv_core_pipe_regwrite_mem_wb
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (1'b0)
  ,.i_pipe_en_n  (hu_hazard_wb)
  ,.i_pipe_in    (ex_mem_pipe_regwrite)
  ,.o_pipe_out   (mem_wb_pipe_regwrite)
);


//----------------------------------//
//-------------WB Stage-------------//
//----------------------------------//
riscv_core_mux4x1
#(
  .XLEN (64)
)
u_riscv_core_mux4x1
(
  .i_mux4x1_in0 (mem_wb_pipe_alu_result)
  ,.i_mux4x1_in1(mem_wb_pipe_read_data)
  ,.i_mux4x1_in2(mem_wb_pipe_pc_plus_offset)
  ,.i_mux4x1_in3(mem_wb_pipe_auipc)
  ,.i_mux4x1_sel(mem_wb_pipe_resultsrc)
  ,.o_mux4x1_out(result_wb)
);


//----------------------------------//
//------------Hazard Unit-----------//
//----------------------------------//
riscv_core_hazard_unit
u_riscv_core_hazard_unit
(
    // RV64I Detection inputs
    .i_hazard_unit_rs1_id         (if_id_pipe_instr[19:15]) // rs1D
    ,.i_hazard_unit_rs2_id        (if_id_pipe_instr[24:20]) // rs2D
    ,.i_hazard_unit_rs1_ex        (id_ex_pipe_rs1)
    ,.i_hazard_unit_rs2_ex        (id_ex_pipe_rs2)
    ,.i_hazard_unit_rd_ex         (id_ex_pipe_rd)
    ,.i_hazard_unit_rd_mem        (ex_mem_pipe_rd)
    ,.i_hazard_unit_rd_wb         (mem_wb_pipe_rd)
    // Control signals inputs
    ,.i_hazard_unit_regwrite_mem  (ex_mem_pipe_regwrite)
    ,.i_hazard_unit_regwrite_wb   (mem_wb_pipe_regwrite)
    ,.i_hazard_unit_resultsrc_ex  (id_ex_pipe_resultsrc)
    ,.i_hazard_unit_pcsrc_ex      (pcsrc_ex)
    // C Extension
    ,.i_hazard_unit_illegal_instr (instr_is_illegal)
    // M Extension
    ,.i_hazard_unit_mdone         (m_ext_done)
    ,.i_hazard_unit_mbusy         (m_ext_busy)
    ,.i_hazard_unit_mdivby0       (m_ext_divby0)
    ,.i_hazard_unit_mof           (m_ext_of)
    // caches requests
    ,.i_hazard_unit_icache_stall  (icache_hu_stall)
    ,.i_hazard_unit_dcache_stall  (dcache_hu_stall)
    // Forwarding outputs
    ,.o_hazard_unit_forwarda_ex   (hu_forward_a)
    ,.o_hazard_unit_forwardb_ex   (hu_forward_b)
    // Stall outputs
    ,.o_hazard_unit_stall_if      (hu_stall_if)
    ,.o_hazard_unit_stall_id      (hu_stall_id)
    ,.o_hazard_unit_stall_ex      (hu_stall_ex)
    ,.o_hazard_unit_stall_mem     (hu_stall_mem)
    ,.o_hazard_unit_stall_wb      (hu_stall_wb)
    // Flush outputs
    ,.o_hazard_unit_flush_id      (hu_flush_id)
    ,.o_hazard_unit_flush_ex      (hu_flush_ex)
    // Exceptions
    ,.o_hazard_unit_exception     (hu_exception)
);
//----------------------------------//

endmodule