/*******************************************************************************
 * Module: ddrc_control
 * Date:2014-05-19  
 * Author: Andrey Filippov
 * Description: Temporary module with DDRC control / command registers
 *
 * Copyright (c) 2014 Elphel, Inc.
 * ddrc_control.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  ddrc_control.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  ddrc_control #(
    parameter AXI_WR_ADDR_BITS=    12,
//    parameter SELECT_ADDR =        'h800, // address to select this module
//    parameter SELECT_ADDR_MASK =   'h800, // address mask to select this  module
//    parameter BUSY_ADDR =          'hc00, // address to generate busy
//    parameter BUSY_ADDR_MASK =     'hc00,  // address mask to generate busy

    parameter CONTROL_ADDR =        'h1000, // AXI write address of control write registers
    parameter CONTROL_ADDR_MASK =   'h1400, // AXI write address of control registers
//    parameter STATUS_ADDR =         'h1400, // AXI write address of status read registers
//    parameter STATUS_ADDR_MASK =    'h1400, // AXI write address of status registers
    parameter BUSY_WR_ADDR =        'h1800, // AXI write address to generate busy
    parameter BUSY_WR_ADDR_MASK =   'h1c00, // AXI write address mask to generate busy
    
//    parameter DLY_LD_ADDR =        'h880,  // address to generate delay load
//    parameter DLY_LD_ADDR_MASK =   'hb80,  // address mask to generate delay load
//    parameter DLY_SET_ADDR =       'h870,  // address to generate delay set
//    parameter DLY_SET_ADDR_MASK =  'hbff,  // address mask to generate delay set
//    parameter RUN_CHN_ADDR =       'h800,  // address to set sequnecer channel and  run (4 LSB-s - channel)
//    parameter RUN_CHN_ADDR_MASK =  'hbf0,  // address mask to generate sequencer channel/run
//    parameter PATTERNS_ADDR =      'h820,  // address to set DQM and DQS patterns (16'h0055)
//    parameter PATTERNS_ADDR_MASK = 'hbff,  // address mask to set DQM and DQS patterns
//    parameter PAGES_ADDR =         'h821,  // address to set buffer pages {port1_page[1:0],port1_int_page[1:0],port0_page[1:0],port0_int_page[1:0]}
//    parameter PAGES_ADDR_MASK =    'hbff,  // address mask to set DQM and DQS patterns
//    parameter CMDA_EN_ADDR =       'h822,  // address to enable('h823)/disable('h822) command/address outputs  
//    parameter CMDA_EN_ADDR_MASK =  'hbfe,  // address mask for command/address outputs
//    parameter EXTRA_ADDR =         'h824,  // address to set extra parameters (currently just inv_clk_div)
//    parameter EXTRA_ADDR_MASK =    'hbff   // address mask for extra parameters

    parameter DLY_LD_REL =        'h080,  // address to generate delay load
    parameter DLY_LD_REL_MASK =   'h380,  // address mask to generate delay load
    parameter DLY_SET_REL =       'h070,  // address to generate delay set
    parameter DLY_SET_REL_MASK =  'h3ff,  // address mask to generate delay set
    parameter RUN_CHN_REL =       'h000,  // address to set sequnecer channel and  run (4 LSB-s - channel)
    parameter RUN_CHN_REL_MASK =  'h3f0,  // address mask to generate sequencer channel/run
    parameter PATTERNS_REL =      'h020,  // address to set DQM and DQS patterns (16'h0055)
    parameter PATTERNS_REL_MASK = 'h3ff,  // address mask to set DQM and DQS patterns
    parameter PAGES_REL =         'h021,  // address to set buffer pages {port1_page[1:0],port1_int_page[1:0],port0_page[1:0],port0_int_page[1:0]}
    parameter PAGES_REL_MASK =    'h3ff,  // address mask to set DQM and DQS patterns
    parameter CMDA_EN_REL =       'h022,  // address to enable('h823)/disable('h822) command/address outputs  
    parameter CMDA_EN_REL_MASK =  'h3fe,  // address mask for command/address outputs
    parameter EXTRA_REL =         'h024,  // address to set extra parameters (currently just inv_clk_div)
    parameter EXTRA_REL_MASK =    'h3ff   // address mask for extra parameters
)(
    input                         clk,
    input                         mclk,
    input                         rst,
    input  [AXI_WR_ADDR_BITS-1:0] pre_waddr,     // AXI write address, before actual writes (to generate busy), valid@start_burst
    input                         start_wburst, // burst start - should generate ~ready (should be AND-ed with !busy internally) 
    input  [AXI_WR_ADDR_BITS-1:0] waddr,        // write address, valid with wr_en
    input                         wr_en,        // write enable 
    input                  [31:0] wdata,        // write data, valid with waddr and wr_en
    output                        busy,          // interface busy (combinatorial delay from start_wburst and pre_addr
// control signals
// control: sequencer run    
    output                 [10:0] run_addr, // Start address of the physical sequencer (MSB = 0 - "manual", 1 -"auto")
    output                 [ 3:0] run_chn,  // channel number to use for I/O buffers
    output                        run_seq,  // single mclk pulse to start sequencer
//    input                        run_done; // output - will go through other channel - sequencer done (add busy?)
// control: delays and mmcm setup    
    output                 [ 7:0] dly_data, // 8-bit IDELAY/ODELAY (fine) and MMCM phase shift
    output                 [ 6:0] dly_addr, // address to select delay register
    output                        ld_delay, // write dly_data to dly_address, one mclk active pulse
    output                        dly_set,      // transfer (activate) all delays simultaneosly, 1 mclk pulse 
// control: additional signals
    output                        cmda_tri,    // tri-state all command and address lines to DDR chip
    output                        inv_clk_div, // invert clk_div to ISERDES
    output                 [ 7:0] dqs_pattern, // DQS pattern during write (normally 8'h55)
    output                 [ 7:0] dqm_pattern, // DQM pattern (just for testing, should be 8'h0)
// control: buffers pages
    output                 [ 1:0] port0_page,     // port 0 buffer read page (to be controlled by arbiter later, set to 2'b0)
    output                 [ 1:0] port0_int_page, // port 0 PHY-side write to buffer page (to be controlled by arbiter later, set to 2'b0)
    output                 [ 1:0] port1_page,     // port 1 buffer write page (to be controlled by arbiter later, set to 2'b0)
    output                 [ 1:0] port1_int_page  // port 1 PHY-side buffer read page (to be controlled by arbiter later, set to 2'b0) 

);
    localparam DLY_LD_ADDR =        CONTROL_ADDR |      DLY_LD_REL;       // address to generate delay load
    localparam DLY_LD_ADDR_MASK =   CONTROL_ADDR_MASK | DLY_LD_REL_MASK;  // address mask to generate delay load
    localparam DLY_SET_ADDR =       CONTROL_ADDR |      DLY_SET_REL;      // address to generate delay set
    localparam DLY_SET_ADDR_MASK =  CONTROL_ADDR_MASK | DLY_SET_REL_MASK; // address mask to generate delay set
    localparam RUN_CHN_ADDR =       CONTROL_ADDR |      RUN_CHN_REL;      // address to set sequnecer channel and  run (4 LSB-s - channel)
    localparam RUN_CHN_ADDR_MASK =  CONTROL_ADDR_MASK | RUN_CHN_REL_MASK; // address mask to generate sequencer channel/run
    localparam PATTERNS_ADDR =      CONTROL_ADDR |      PATTERNS_REL;     // address to set DQM and DQS patterns (16'h0055)
    localparam PATTERNS_ADDR_MASK = CONTROL_ADDR_MASK | PATTERNS_REL_MASK;// address mask to set DQM and DQS patterns
    localparam PAGES_ADDR =         CONTROL_ADDR |      PAGES_REL;        // address to set buffer pages {port1_page[1:0],port1_int_page[1:0],port0_page[1:0],port0_int_page[1:0]}
    localparam PAGES_ADDR_MASK =    CONTROL_ADDR_MASK | PAGES_REL_MASK;   // address mask to set DQM and DQS patterns
    localparam CMDA_EN_ADDR =       CONTROL_ADDR |      CMDA_EN_REL;      // address to enable('h823)/disable('h822) command/address outputs  
    localparam CMDA_EN_ADDR_MASK =  CONTROL_ADDR_MASK | CMDA_EN_REL_MASK; // address mask for command/address outputs
    localparam EXTRA_ADDR =         CONTROL_ADDR |      EXTRA_REL;        // address to set extra parameters (currently just inv_clk_div)
    localparam EXTRA_ADDR_MASK =    CONTROL_ADDR_MASK | EXTRA_REL_MASK;   // address mask for extra parameters

    reg busy_r=0;
    reg selected=0;
    reg selected_busy=0;
//(* keep = "true" *)
    wire fifo_half_empty; // just debugging with (* keep = "true" *)
    wire [AXI_WR_ADDR_BITS-1:0] waddr_fifo_out;
    wire                 [31:0] wdata_fifo_out;
//    reg                         fifo_re; // wrong, need to have (fifo!=1) || !re 
    wire                        fifo_nempty;
    wire                        fifo_re=fifo_nempty; // try simpler
    reg  [AXI_WR_ADDR_BITS-1:0] waddr_fifo_out_r;
    reg                  [31:0] wdata_fifo_out_r;
    reg                         dly_ld_r=0;
    reg                         dly_set_r=0;
    reg                         run_seq_r=0;
    reg                  [ 7:0] dqs_pattern_r;    // DQS pattern during write (normally 8'h55)
    reg                  [ 7:0] dqm_pattern_r;    // DQM pattern (just for testing, should be 8'h0)
    reg                  [ 1:0] port0_page_r;     // port 0 buffer read page (to be controlled by arbiter later, set to 2'b0)
    reg                  [ 1:0] port0_int_page_r; // port 0 PHY-side write to buffer page (to be controlled by arbiter later, set to 2'b0)
    reg                  [ 1:0] port1_page_r;     // port 1 buffer write page (to be controlled by arbiter later, set to 2'b0)
    reg                  [ 1:0] port1_int_page_r; // port 1 PHY-side buffer read page (to be controlled by arbiter later, set to 2'b0) 
    reg                         cmda_en_r;        // enable (tri-state off) all command and address lines to DDR chip
    reg                         inv_clk_div_r;    // invert clk_div to ISERDES

    assign ld_delay = dly_ld_r;
    assign dly_set =  dly_set_r;
    assign dly_data = wdata_fifo_out_r[ 7:0]; // WARNING: [Synth 8-3936] Found unconnected internal register 'wdata_fifo_out_r_reg' and it is trimmed from '32' to '11' bits. [ddrc_control.v:100]
    assign dly_addr = waddr_fifo_out_r[ 6:0]; //WARNING: [Synth 8-3936] Found unconnected internal register 'waddr_fifo_out_r_reg' and it is trimmed from '12' to '7' bits. [ddrc_control.v:101]
    assign run_addr = wdata_fifo_out_r[10:0];
    assign run_chn =  waddr_fifo_out_r[3:0];
    assign run_seq =  run_seq_r;

    assign busy=busy_r && (start_wburst?(((pre_waddr ^ BUSY_WR_ADDR) & BUSY_WR_ADDR_MASK)==0): selected_busy);

    assign dqs_pattern =    dqs_pattern_r[7:0];
    assign dqm_pattern =    dqm_pattern_r[7:0];
    assign port0_page =     port0_page_r[1:0];
    assign port0_int_page = port0_int_page_r[1:0];
    assign port1_page =     port1_page_r[1:0];
    assign port1_int_page = port1_int_page_r[1:0];
    assign cmda_tri =       ~cmda_en_r;
    assign inv_clk_div =    inv_clk_div_r;

    always @ (posedge clk or posedge rst) begin
        if (rst)               selected <= 1'b0;
        else if (start_wburst) selected <= ((pre_waddr ^ CONTROL_ADDR) & CONTROL_ADDR_MASK)==0;
        if (rst)               selected_busy <= 1'b0;
        else if (start_wburst) selected_busy <= ((pre_waddr ^ BUSY_WR_ADDR) & BUSY_WR_ADDR_MASK)==0;
        if (rst)               busy_r <= 1'b0;
//        else if (start_wburst) busy_r <= !fifo_half_empty;
        else                   busy_r <= !fifo_half_empty;
        
    end

    /* FIFO to cross clock boundary */
    fifo_cross_clocks #(
        .DATA_WIDTH  (AXI_WR_ADDR_BITS+32),
        .DATA_DEPTH  (4)
    ) fifo_cross_clocks_i (
        .rst         (rst), // input
        .rclk        (mclk), // input
        .wclk        (clk), // input
        .we          (wr_en && selected), // input
        .re          (fifo_re), // input
        .data_in     ({waddr[AXI_WR_ADDR_BITS-1:0],wdata[31:0]}), // input[15:0] 
        .data_out    ({waddr_fifo_out[AXI_WR_ADDR_BITS-1:0],wdata_fifo_out[31:0]}), // output[15:0] 
        .nempty      (fifo_nempty), // output
        .half_empty  (fifo_half_empty) // output
    );
    always @ (posedge rst or posedge mclk) begin
  //      if (rst) fifo_re <= 1'b0;
  //      else     fifo_re <= fifo_nempty;
        if (rst) dly_ld_r <= 1'b0;
        else     dly_ld_r <= fifo_re && (((waddr_fifo_out ^ DLY_LD_ADDR) & DLY_LD_ADDR_MASK)==0);
        if (rst) dly_set_r <= 1'b0;
        else     dly_set_r <= fifo_re && (((waddr_fifo_out ^ DLY_SET_ADDR) & DLY_SET_ADDR_MASK)==0);
        if (rst) run_seq_r <= 1'b0;
        else     run_seq_r <= fifo_re && (((waddr_fifo_out ^ RUN_CHN_ADDR) & RUN_CHN_ADDR_MASK)==0);

        if (rst) {dqm_pattern_r,dqs_pattern_r} <= 16'h0055;
        else if (fifo_re && (((waddr_fifo_out ^ PATTERNS_ADDR) & PATTERNS_ADDR_MASK)==0))
                 {dqm_pattern_r,dqs_pattern_r} <= wdata_fifo_out[15:0];

        if (rst) {port1_page_r[1:0],port1_int_page_r[1:0],port0_page_r[1:0],port0_int_page_r[1:0]} <= 8'h00;
        else if (fifo_re && (((waddr_fifo_out ^ PAGES_ADDR) & PAGES_ADDR_MASK)==0))
                 {port1_page_r[1:0],port1_int_page_r[1:0],port0_page_r[1:0],port0_int_page_r[1:0]} <= wdata_fifo_out[7:0];
        
        if (rst) cmda_en_r <= 1'b0;
        else if (fifo_re && (((waddr_fifo_out ^ CMDA_EN_ADDR) & CMDA_EN_ADDR_MASK)==0))
                 cmda_en_r <= waddr_fifo_out[0];

        if (rst) inv_clk_div_r <= 1'b0;
        else if (fifo_re && (((waddr_fifo_out ^ EXTRA_ADDR) & EXTRA_ADDR_MASK)==0))
                 inv_clk_div_r <= wdata_fifo_out[0];

    end
    always @ (posedge mclk) begin
        waddr_fifo_out_r <= waddr_fifo_out;
        wdata_fifo_out_r <= wdata_fifo_out;
    end
    


endmodule
