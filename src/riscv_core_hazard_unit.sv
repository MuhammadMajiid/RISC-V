// `include "lookup.sv"

module riscv_core_hazard_unit
(

    // RV64I Detection inputs
    input logic [4:0] i_hazard_unit_rs1_id,
    input logic [4:0] i_hazard_unit_rs2_id,
    input logic [4:0] i_hazard_unit_rs1_ex,
    input logic [4:0] i_hazard_unit_rs2_ex,
    input logic [4:0] i_hazard_unit_rd_ex,
    input logic [4:0] i_hazard_unit_rd_mem,
    input logic [4:0] i_hazard_unit_rd_wb,

    // Control signals inputs
    input logic i_hazard_unit_regwrite_mem,
    input logic i_hazard_unit_regwrite_wb,
    input logic [1:0] i_hazard_unit_resultsrc_ex,
    input logic i_hazard_unit_pcsrc_ex,

    // C Extension input
    input logic i_hazard_unit_illegal_instr,

    // M Extension inputs
    input logic i_hazard_unit_mdone,
    input logic i_hazard_unit_mbusy,
    input logic i_hazard_unit_mdivby0,
    input logic i_hazard_unit_mof,

    // Forwarding outputs
    output logic [1:0] o_hazard_unit_forwarda_ex,
    output logic [1:0] o_hazard_unit_forwardb_ex,

    // Stall outputs
    output logic o_hazard_unit_stall_if,
    output logic o_hazard_unit_stall_id,
    output logic o_hazard_unit_stall_ex,
    output logic o_hazard_unit_stall_mem,
    output logic o_hazard_unit_stall_wb,

    // Flush outputs
    output logic o_hazard_unit_flush_id,
    output logic o_hazard_unit_flush_ex,

    // Exceptions
    output logic o_hazard_unit_exception
);

// Internals
logic lwstall_detection;
logic mstall_detection;

//------------------------------Forwarding------------------------------\\

always_comb 
begin : forwarding_proc

    // Forwarding SrcA
    if ((i_hazard_unit_rs1_ex == i_hazard_unit_rd_mem) && i_hazard_unit_regwrite_mem && (i_hazard_unit_rs1_ex != 5'b0)) 
    begin
        o_hazard_unit_forwarda_ex = 2'b10;
    end
    else if ((i_hazard_unit_rs1_ex == i_hazard_unit_rd_wb) && i_hazard_unit_regwrite_wb && (i_hazard_unit_rs1_ex != 5'b0)) 
    begin
        o_hazard_unit_forwarda_ex = 2'b01;
    end
    else 
    begin
        o_hazard_unit_forwarda_ex = 2'b00;
    end
    
    // Forwarding SrcB
    if ((i_hazard_unit_rs2_ex == i_hazard_unit_rd_mem) && i_hazard_unit_regwrite_mem && (i_hazard_unit_rs2_ex != 5'b0)) 
    begin
        o_hazard_unit_forwardb_ex = 2'b10;
    end
    else if ((i_hazard_unit_rs2_ex == i_hazard_unit_rd_wb) && i_hazard_unit_regwrite_wb && (i_hazard_unit_rs2_ex != 5'b0)) 
    begin
        o_hazard_unit_forwardb_ex = 2'b01;
    end
    else 
    begin
        o_hazard_unit_forwardb_ex = 2'b00;
    end

end

//---------------------------------Stall---------------------------------\\

always_comb 
begin : stall_proc
    lwstall_detection = ((i_hazard_unit_resultsrc_ex == 2'b01) && ((i_hazard_unit_rs1_id == i_hazard_unit_rd_ex) || (i_hazard_unit_rs2_id == i_hazard_unit_rd_ex)));
    mstall_detection  = (i_hazard_unit_mbusy && !i_hazard_unit_mdone);
    o_hazard_unit_stall_if  = lwstall_detection || mstall_detection;
    o_hazard_unit_stall_id  = lwstall_detection || mstall_detection;
    o_hazard_unit_stall_ex  = mstall_detection;
    o_hazard_unit_stall_mem = mstall_detection;
    o_hazard_unit_stall_wb  = mstall_detection;
end

//---------------------------------Flush---------------------------------\\

always_comb 
begin : flush_proc
    o_hazard_unit_flush_ex = (lwstall_detection || i_hazard_unit_pcsrc_ex);
    o_hazard_unit_flush_id = i_hazard_unit_pcsrc_ex;
end

//---------------------------------Exceptions---------------------------------\\
always_comb begin : exceptions_proc
    o_hazard_unit_exception = (i_hazard_unit_illegal_instr || i_hazard_unit_mdivby0 || i_hazard_unit_mof);
end
endmodule