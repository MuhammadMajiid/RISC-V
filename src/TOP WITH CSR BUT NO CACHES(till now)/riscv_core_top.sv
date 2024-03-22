module riscv_core_top 
(
  // Global inputs
  input  logic i_riscv_core_clk,
  input  logic i_riscv_core_rst_n,
  input  logic i_riscv_core_external_interrupt,
  output logic o_riscv_core_ack
);
//-------------Local Parameters-------------//

//-------------IF Intermediate Signals-------------//
logic [63:0] if_id_pipe_pc;
logic [63:0] if_pipe_pcf_new;
logic [63:0] compressed_offset;
logic [63:0] if_id_pipe_pc_plus_offset;
logic [31:0] if_id_pipe_instr;
logic [63:0] pcf;
logic [63:0] pc_plus_offset_if;
logic [63:0] mux_to_stg2;
logic [31:0] instr;
logic [31:0] c_ext_instr_out;
logic        instr_is_compressed;
logic        instr_is_illegal;

//-------------ID Intermediate Signals-------------//
logic [63:0] id_ex_pipe_imm;
logic [63:0] id_ex_pipe_rd1;
logic [63:0] id_ex_pipe_rd2;
logic [63:0] id_ex_pipe_pc;
logic [63:0] id_ex_pipe_pc_plus_offset;
logic [4:0]  id_ex_pipe_rd;
logic [4:0]  id_ex_pipe_rs1;
logic [4:0]  id_ex_pipe_rs2;
logic [3:0]  id_ex_pipe_alu_control;
logic [2:0]  id_ex_pipe_funct3;
logic [1:0]  id_ex_pipe_resultsrc;
logic [1:0]  id_ex_pipe_size;
logic        id_ex_pipe_alu_srcb;
logic        id_ex_pipe_branch;
logic        id_ex_pipe_isword;
logic        id_ex_pipe_jump;
logic        id_ex_pipe_ldext;
logic        id_ex_pipe_uctrl;
logic        id_ex_pipe_memwrite;
logic        id_ex_pipe_regwrite;
logic [63:0] rd1_id;
logic [63:0] rd2_id;
logic [63:0] immext_id;
logic [3:0]  alu_control_id;
logic [2:0]  immsrc_id;
logic [1:0]  resultsrc_id;
logic [1:0]  size_id;
logic        alu_op_id;
logic        uctrl_id;
logic        regwrite_id;
logic        alusrc_id;
logic        memwrite_id;
logic        branch_id;
logic        jump_id;
logic        ldext_id;
logic        isword_id;
logic        bjreg_id;
logic        id_ex_pipe_bjreg;
logic        im_sel_id;
logic        id_ex_pipe_im_sel;
logic        new_mux_sel_id;
logic        id_ex_pipe_new_mux_sel;

//-------------EX Intermediate Signals-------------//
logic [63:0] ex_mem_pipe_alu_result;
logic [63:0] ex_mem_pipe_wd;
logic [63:0] ex_mem_pipe_pc_plus_offset;
logic [4:0]  ex_mem_pipe_rd;
logic [1:0]  ex_mem_pipe_resultsrc;
logic [1:0]  ex_mem_pipe_size;
logic        ex_mem_pipe_memwrite;
logic        ex_mem_pipe_ldext;
logic        ex_mem_pipe_regwrite;
logic [63:0] src_a_ex;
logic [63:0] src_b_ex;
logic [63:0] src_b_out;
logic [63:0] alu_result_ex;
logic [63:0] m_ext_res;
logic [63:0] arith_result_ex;
logic [63:0] pc_plus_imm;
logic [63:0] auipc;
logic        istaken_ex;
logic        pcsrc_ex;
logic        m_ext_done;
logic        m_ext_busy;
logic        m_ext_divby0;
logic        m_ext_of;

logic [63:0] new_mux_out;

//-------------MEM Intermediate Signals------------//
logic [63:0] read_data_mem;
logic [63:0] mem_wb_pipe_alu_result;
logic [63:0] mem_wb_pipe_read_data;
logic [63:0] mem_wb_pipe_pc_plus_offset;
logic [4:0]  mem_wb_pipe_rd;
logic [1:0]  mem_wb_pipe_resultsrc;
logic        mem_wb_pipe_regwrite; 

//-------------WB Intermediate Signals-------------//
logic [63:0] result_wb;

//-------------HU Intermediate Signals-------------//
logic [1:0]  hu_forward_a;
logic [1:0]  hu_forward_b;
logic        hu_stall_if;
logic        hu_stall_id;
logic        hu_stall_ex;
logic        hu_stall_mem;
logic        hu_stall_wb;
logic        hu_flush_id;
logic        hu_flush_ex;
logic        hu_exception;

//----------------CSR Signals------------------------//
//---FETCH STAGE---//
logic [63:0] mepc_if;
logic [63:0] trap_addr_if;
logic [63:0] PCF_NEW;
logic [63:0] TRAP_PC;
//---DECODE STAGE---//
logic csr_src_sel_id;
logic [1:0] csr_op_id;
logic [63:0] csr_src_id;
logic ecall_id;
logic ebreak_id;
logic mret_id;
//---EXECUTION STAGE---//
logic [31:0] instr_ex;
logic [1:0] csr_op_ex;
logic [63:0] csr_src_ex;
logic mret_ex;
logic instr_addr_miss_ex;
//---MEMORY STAGE---//
logic [1:0] csr_op_mem;
logic [31:0] instr_mem;
logic mret_mem;
logic [63:0] csr_src_mem;
logic [63:0] pc_mem;
//---WRITE BACK STAGE---//
logic [1:0] csr_op_wb;
logic [31:0] instr_wb;
logic mret_wb;
logic [63:0] csr_src_wb;
logic trap_cntrl_wb;
logic pc_cntrl_wb;
logic [63:0] csr_rdata_wb;
logic csr_mem_flush;
logic csr_ex_flush;
logic csr_id_flush;
logic csr_if_flush;
logic [63:0] csr_pc_trap_stg1;
logic [63:0] csr_pc;
logic [63:0] csr_instr_stg1;
logic [63:0] csr_instr;


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
u_riscv_core_mux2x1_TRAP_MUX
(
  .i_mux2x1_in0 (trap_addr_if)
  ,.i_mux2x1_in1(mepc_if)
  ,.i_mux2x1_sel(trap_cntrl_wb)
  ,.o_mux2x1_out(TRAP_PC)
);

riscv_core_mux2x1
#(
  .XLEN (64)
)
u_riscv_core_mux2x1_stg3
(
  .i_mux2x1_in0 (pcf)
  ,.i_mux2x1_in1(TRAP_PC)
  ,.i_mux2x1_sel(pc_cntrl_wb)
  ,.o_mux2x1_out(PCF_NEW)
);

riscv_core_pipe //pc FF
#(
  .W_PIPE_BUS (64)
)
u_riscv_core_pipe_pcf_if
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (1'b0)
  ,.i_pipe_en_n  (hu_stall_if)
  ,.i_pipe_in    (PCF_NEW)
  ,.o_pipe_out   (if_pipe_pcf_new)
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
  .i_64bit_adder_srcA   (if_pipe_pcf_new)
  ,.i_64bit_adder_srcB  (compressed_offset)
  ,.o_64bit_adder_result(pc_plus_offset_if)
);

riscv_core_imem
#(
  .ALEN (64)
  ,.ILEN(32)
  ,.MWID(8)
  ,.MLEN(10000)
)
u_riscv_core_imem
(
  .i_imem_rst_n    (i_riscv_core_rst_n)
  ,.i_imem_address (if_pipe_pcf_new)
  ,.o_imem_rdata   (instr)
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
u_riscv_core_pipe_pc_if_id
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (hu_flush_id)
  ,.i_pipe_en_n  (hu_stall_id)
  ,.i_pipe_in    (if_pipe_pcf_new)
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
  ,.i_alu_decoder_funct7_0  (if_id_pipe_instr[25])
  ,.i_alu_decoder_opcode_5  (if_id_pipe_instr[5])
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
  ,.o_main_decoder_new_mux_sel(new_mux_sel_id)
  ,.o_main_decoder_src_sel(csr_src_sel_id)
  ,.o_main_decoder_op(csr_op_id)
);


riscv_core_csr_control_signals
u_riscv_core_csr_conrtol_signals
(
.i_csr_control_instr(if_id_pipe_instr)
,.o_csr_control_ecall(ecall_id)
,.o_csr_control_ebreak(ebreak_id)
,.o_csr_control_mret(mret_id)
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

riscv_core_mux2x1
#(
  .XLEN (64)
)
u_riscv_core_mux2x1_csr_src
(
  .i_mux2x1_in0 (rd1_id)
  ,.i_mux2x1_in1(immext_id)
  ,.i_mux2x1_sel(csr_src_sel_id)
  ,.o_mux2x1_out(csr_src_id)
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
  .W_PIPE_BUS (32)
)
u_riscv_core_pipe_csr_addr_id_ex_pipe
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (hu_flush_ex)
  ,.i_pipe_en_n  (hu_stall_ex)
  ,.i_pipe_in    (if_id_pipe_instr)
  ,.o_pipe_out   (instr_ex)
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

riscv_core_pipe 
#(
  .W_PIPE_BUS (64)
)
u_riscv_core_pipe_csr_src_id_ex
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (hu_flush_ex)
  ,.i_pipe_en_n  (hu_stall_ex)
  ,.i_pipe_in    (csr_src_id)
  ,.o_pipe_out   (csr_src_ex)
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
u_riscv_core_pipe_cre_op_id_ex
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (hu_flush_ex)
  ,.i_pipe_en_n  (hu_stall_ex)
  ,.i_pipe_in    (csr_op_id)
  ,.o_pipe_out   (csr_op_ex)
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
u_riscv_core_pipe_mret_id_ex
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (hu_flush_ex)
  ,.i_pipe_en_n  (hu_stall_ex)
  ,.i_pipe_in    (mret_id)
  ,.o_pipe_out   (mret_ex)
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

riscv_core_pipe 
#(
  .W_PIPE_BUS (1)
)
u_riscv_core_pipe_new_mux_id_ex
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (hu_flush_ex)
  ,.i_pipe_en_n  (hu_stall_ex)
  ,.i_pipe_in    (new_mux_sel_id)
  ,.o_pipe_out   (id_ex_pipe_new_mux_sel)
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
  ,.o_mul_div_div_by_zero(m_ext_divby0)/////////////////for csr direct
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
  ,.o_branch_unit_addr_mismatch(instr_addr_miss_ex) ////////////////for CSR direct
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


riscv_core_mux2x1
#(
  .XLEN (64)
)
u_riscv_core_mux2x1_new_mux
(
  .i_mux2x1_in0 (arith_result_ex)
  ,.i_mux2x1_in1(auipc)
  ,.i_mux2x1_sel(id_ex_pipe_new_mux_sel)
  ,.o_mux2x1_out(new_mux_out)
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
  ,.i_pipe_en_n  (hu_stall_mem)
  ,.i_pipe_in    (new_mux_out)
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
  ,.i_pipe_en_n  (hu_stall_mem)
  ,.i_pipe_in    (src_b_out)
  ,.o_pipe_out   (ex_mem_pipe_wd)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (64)
)
u_riscv_core_pipe_csr_src_ex_mem
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (1'b0)
  ,.i_pipe_en_n  (hu_stall_mem)
  ,.i_pipe_in    (csr_src_ex)
  ,.o_pipe_out   (csr_src_mem)
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
  ,.i_pipe_en_n  (hu_stall_mem)
  ,.i_pipe_in    (id_ex_pipe_rd)
  ,.o_pipe_out   (ex_mem_pipe_rd)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (64)
)
u_riscv_core_pipe_pc_plus_ex_mem
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (1'b0)
  ,.i_pipe_en_n  (hu_stall_mem)
  ,.i_pipe_in    (id_ex_pipe_pc_plus_offset)
  ,.o_pipe_out   (ex_mem_pipe_pc_plus_offset)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (64)
)
u_riscv_core_pipe_instruction_ex_mem
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (1'b0)
  ,.i_pipe_en_n  (hu_stall_mem)
  ,.i_pipe_in    (instr_ex)
  ,.o_pipe_out   (instr_mem)
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
  ,.i_pipe_en_n  (hu_stall_mem)
  ,.i_pipe_in    (id_ex_pipe_pc)
  ,.o_pipe_out   (pc_mem)
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
  ,.i_pipe_en_n  (hu_stall_mem)
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
  ,.i_pipe_en_n  (hu_stall_mem)
  ,.i_pipe_in    (id_ex_pipe_memwrite)
  ,.o_pipe_out   (ex_mem_pipe_memwrite)
);


riscv_core_pipe 
#(
  .W_PIPE_BUS (1)
)
u_riscv_core_pipe_mret_ex_mem
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (1'b0)
  ,.i_pipe_en_n  (hu_stall_mem)
  ,.i_pipe_in    (mret_ex)
  ,.o_pipe_out   (mret_mem)
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
  ,.i_pipe_en_n  (hu_stall_mem)
  ,.i_pipe_in    (id_ex_pipe_size)
  ,.o_pipe_out   (ex_mem_pipe_size)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (2)
)
u_riscv_core_pipe_csr_op_ex_mem
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (1'b0)
  ,.i_pipe_en_n  (hu_stall_mem)
  ,.i_pipe_in    (csr_op_ex)
  ,.o_pipe_out   (csr_op_mem)
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
  ,.i_pipe_en_n  (hu_stall_mem)
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
  ,.i_pipe_en_n  (hu_stall_mem)
  ,.i_pipe_in    (id_ex_pipe_regwrite)
  ,.o_pipe_out   (ex_mem_pipe_regwrite)
);

//----------------------------------//
//-------------MEM Stage------------//
//----------------------------------//
riscv_core_data_mem
#(
  .XLEN (64)
  ,.MWID(8)
  ,.MLEN(10000)
)
u_riscv_core_data_mem
(
  .i_data_mem_clk          (i_riscv_core_clk)
  ,.i_data_mem_rst_n       (i_riscv_core_rst_n)
  ,.i_data_mem_w_en        (ex_mem_pipe_memwrite)/////csr also needed
  ,.i_data_mem_ld_extend   (ex_mem_pipe_ldext)
  ,.i_data_mem_r_w_size    (ex_mem_pipe_size)
  ,.i_data_mem_address     (ex_mem_pipe_alu_result)
  ,.i_data_mem_wdata       (ex_mem_pipe_wd)
  ,.o_data_mem_rdata       (read_data_mem)
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
  ,.i_pipe_en_n  (hu_stall_wb)
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
  ,.i_pipe_en_n  (hu_stall_wb)
  ,.i_pipe_in    (read_data_mem)
  ,.o_pipe_out   (mem_wb_pipe_read_data)
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
  ,.i_pipe_en_n  (hu_stall_wb)
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
  ,.i_pipe_en_n  (hu_stall_wb)
  ,.i_pipe_in    (ex_mem_pipe_rd)
  ,.o_pipe_out   (mem_wb_pipe_rd)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (64)
)
u_riscv_core_pipe_instruction_mem_wb
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (1'b0)
  ,.i_pipe_en_n  (hu_stall_mem)
  ,.i_pipe_in    (instr_mem)
  ,.o_pipe_out   (instr_wb)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (64)
)
u_riscv_core_pipe_csr_src_mem_wb
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (1'b0)
  ,.i_pipe_en_n  (hu_stall_mem)
  ,.i_pipe_in    (csr_src_mem)
  ,.o_pipe_out   (csr_src_wb)
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
  ,.i_pipe_en_n  (hu_stall_wb)
  ,.i_pipe_in    (ex_mem_pipe_resultsrc)
  ,.o_pipe_out   (mem_wb_pipe_resultsrc)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (2)
)
u_riscv_core_pipe_csr_op_mem_wb
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (1'b0)
  ,.i_pipe_en_n  (hu_stall_wb)
  ,.i_pipe_in    (csr_op_mem)
  ,.o_pipe_out   (csr_op_wb)
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
  ,.i_pipe_en_n  (hu_stall_wb)
  ,.i_pipe_in    (ex_mem_pipe_regwrite)
  ,.o_pipe_out   (mem_wb_pipe_regwrite)
);

riscv_core_pipe 
#(
  .W_PIPE_BUS (1)
)
u_riscv_core_pipe_mret_mem_wb
(
  .i_pipe_clk    (i_riscv_core_clk)
  ,.i_pipe_rst_n (i_riscv_core_rst_n)
  ,.i_pipe_clr   (1'b0)
  ,.i_pipe_en_n  (hu_stall_wb)
  ,.i_pipe_in    (mret_mem)
  ,.o_pipe_out   (mret_wb)
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
  ,.i_mux4x1_in3(csr_rdata_wb)
  ,.i_mux4x1_sel(mem_wb_pipe_resultsrc)
  ,.o_mux4x1_out(result_wb)
);


riscv_core_csr_unit
(
  .i_csr_unit_clk(i_riscv_core_clk)
  ,.i_csr_unit_rst_n(i_riscv_core_rst_n)
  ,.i_csr_unit_pc(csr_pc)
  ,.i_csr_unit_mem_wen(ex_mem_pipe_memwrite)
  ,.i_csr_unit_fault_addr()/////////////////from cache
  ,.i_csr_unit_instr(csr_instr)
    //external interrupts
  ,.i_csr_unit_mexternal(i_riscv_core_external_interrupt)
  ,.o_csr_unit_ack(o_riscv_core_ack)
    //CSR instructions signals      
  ,.i_csr_unit_csr_wen()/////////////after main decoder editing
  ,.i_csr_unit_op(csr_op_wb)
  ,.i_csr_unit_src(csr_src_wb)
  ,.i_csr_unit_csr_addr(instr_wb[31:20])
  ,.o_csr_unit_csr_rdata(csr_rdata_wb)
    //exception handling signals
  ,.o_csr_unit_irq_handler(trap_addr_id)
  ,.o_csr_unit_mepc(mepc_if)
  ,.o_csr_unit_addr_ctrl(trap_cntrl_wb)
  ,.o_csr_unit_mux1(pc_cntrl_wb)
    //machine mode instructions
  ,.i_csr_unit_mret_id(mret_id)
  ,.i_csr_unit_mret_wb(mret_wb)
  ,.i_csr_unit_ecall(ecall_id)
  ,.i_csr_unit_ebreak(ebreak_id)
    //exception signals
  ,.i_csr_unit_illegal_instr_id()/////after main decder editing
  ,.i_csr_unit_illegal_instr_exe(m_ext_divby0)//still there's some editing here
  ,.i_csr_unit_instr_addr_misaligned(instr_addr_miss_ex)
  ,.i_csr_unit_lw_access_fault()//from cache
  ,.i_csr_unit_sw_access_fault()//from cache
    //flush signals
  ,.o_csr_unit_if_flush(csr_if_flush)//for hazard don't forget
  ,.o_csr_unit_id_flush(csr_id_flush)
  ,.o_csr_unit_exe_flush(csr_ex_flush)
  ,.o_csr_unit_mem_flush(csr_mem_flush)
);

riscv_core_mux2x1
#(
  .XLEN (64)
)
u_riscv_core_mux2x1_stg1_pc_trap
(
  .i_mux2x1_in0 (if_id_pipe_pc)
  ,.i_mux2x1_in1(id_ex_pipe_pc)
  ,.i_mux2x1_sel(csr_ex_flush)
  ,.o_mux2x1_out(csr_pc_trap_stg1)
);

riscv_core_mux2x1
#(
  .XLEN (64)
)
u_riscv_core_mux2x1_stg2_pc_trap
(
  .i_mux2x1_in0 (csr_pc_trap_stg1)
  ,.i_mux2x1_in1(pc_mem)
  ,.i_mux2x1_sel(csr_mem_flush)
  ,.o_mux2x1_out(csr_pc)
);

riscv_core_mux2x1
#(
  .XLEN (64)
)
u_riscv_core_mux2x1_stg1_instr_csr
(
  .i_mux2x1_in0 (if_id_pipe_instr)
  ,.i_mux2x1_in1(instr_ex)
  ,.i_mux2x1_sel(csr_ex_flush)
  ,.o_mux2x1_out(csr_instr_stg1)
);

riscv_core_mux2x1
#(
  .XLEN (64)
)
u_riscv_core_mux2x1_stg2_instr_csr
(
  .i_mux2x1_in0 (csr_instr_stg1)
  ,.i_mux2x1_in1(instr_mem)
  ,.i_mux2x1_sel(csr_mem_flush)
  ,.o_mux2x1_out(csr_instr)
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