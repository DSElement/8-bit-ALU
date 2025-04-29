/*module control_unit (
    input wire clk,
    input wire reset,
    input wire start,
    input wire [1:0] op_code,   // 00 add, 01 sub, 10 mul, 11 div
    input wire booth_done,
    input wire divider_done,
    output wire adder_en,
    output wire subtractor_en,
    output wire booth_start,
    output wire divider_start,
    output wire load_operands,
    output wire alu_done
);

    // State encoding (one-hot)
    localparam IDLE        = 9'b000000001;
    localparam LOAD        = 9'b000000010;
    localparam ADD_EXEC    = 9'b000000100;
    localparam SUB_EXEC    = 9'b000001000;
    localparam MUL_EXEC    = 9'b000010000;
    localparam WAIT_MUL    = 9'b000100000;
    localparam DIV_EXEC    = 9'b001000000;
    localparam WAIT_DIV    = 9'b010000000;
    localparam DONE        = 9'b100000000;

    wire [8:0] current_state;
    wire [8:0] next_state;

    // State register
    register #(9) state_reg (
        .clk(clk),
        .d(next_state),
        .q(current_state)
    );

    // Next-state logic
    assign next_state = (reset) ? IDLE :
                        (current_state == IDLE)     ? (start ? LOAD : IDLE) :
                        (current_state == LOAD)     ? 
                            (op_code == 2'b00 ? ADD_EXEC :
                             op_code == 2'b01 ? SUB_EXEC :
                             op_code == 2'b10 ? MUL_EXEC :
                             DIV_EXEC) :
                        (current_state == ADD_EXEC)  ? DONE :
                        (current_state == SUB_EXEC)  ? DONE :
                        (current_state == MUL_EXEC)  ? WAIT_MUL :
                        (current_state == WAIT_MUL)  ? (booth_done ? DONE : WAIT_MUL) :
                        (current_state == DIV_EXEC)  ? WAIT_DIV :
                        (current_state == WAIT_DIV)  ? (divider_done ? DONE : WAIT_DIV) :
                        (current_state == DONE)      ? IDLE :
                        IDLE; // fallback

    // Output logic
    assign load_operands = (current_state == LOAD);
    assign adder_en      = (current_state == ADD_EXEC);
    assign subtractor_en = (current_state == SUB_EXEC);
    assign booth_start   = (current_state == MUL_EXEC);
    assign divider_start = (current_state == DIV_EXEC);
    assign alu_done      = (current_state == DONE);

endmodule

`timescale 1ns / 1ps

module control_unit_tb;

    // Inputs
    reg clk;
    reg reset;
    reg start;
    reg [1:0] op_code;
    reg booth_done;
    reg divider_done;

    // Outputs
    wire adder_en;
    wire subtractor_en;
    wire booth_start;
    wire divider_start;
    wire load_operands;
    wire alu_done;

    // Instantiate the Control Unit
    control_unit uut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .op_code(op_code),
        .booth_done(booth_done),
        .divider_done(divider_done),
        .adder_en(adder_en),
        .subtractor_en(subtractor_en),
        .booth_start(booth_start),
        .divider_start(divider_start),
        .load_operands(load_operands),
        .alu_done(alu_done)
    );

    // Clock generator
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns clock
    end

    // Test sequence
    initial begin
        // Initialize
        reset = 1;
        start = 0;
        op_code = 2'b00;
        booth_done = 0;
        divider_done = 0;

        #20;
        reset = 0;

        // ======== Test ADD Operation (00) ========
        #10;
        op_code = 2'b00; // ADD
        start = 1;
        #10;
        start = 0;

        #50; // Let FSM run through ADD

        // ======== Test SUB Operation (01) ========
        #20;
        op_code = 2'b01; // SUB
        start = 1;
        #10;
        start = 0;

        #50; // Let FSM run through SUB

        // ======== Test MUL Operation (10) ========
        #20;
        op_code = 2'b10; // MUL
        start = 1;
        #10;
        start = 0;

        // Wait some time, then simulate booth_done
        #50;
        booth_done = 1;
        #10;
        booth_done = 0;

        #50;

        // ======== Test DIV Operation (11) ========
        #20;
        op_code = 2'b11; // DIV
        start = 1;
        #10;
        start = 0;

        // Wait some time, then simulate divider_done
        #50;
        divider_done = 1;
        #10;
        divider_done = 0;

        #100;
        $finish;
    end

    // Monitor important stuff
    initial begin
        $monitor("TIME=%0t | start=%b op_code=%b booth_done=%b divider_done=%b || load_operands=%b adder_en=%b subtractor_en=%b booth_start=%b divider_start=%b alu_done=%b",
            $time,
            start,
            op_code,
            booth_done,
            divider_done,
            load_operands,
            adder_en,
            subtractor_en,
            booth_start,
            divider_start,
            alu_done
        );
    end

endmodule*/

module control_unit (
    input wire clk,
    input wire reset,
    input wire start,
    input wire [1:0] op_code,      // 00=ADD, 01=SUB, 10=MUL, 11=DIV
    input wire [1:0] booth_bits,   // Q[0], Q-1 bits
    input wire booth_counter_done, // booth internal counter done
    input wire divider_sign_R,     // R[7] from divider
    input wire divider_counter_done, // divider counter done
    output wire adder_en,
    output wire subtractor_en,
    output wire booth_load,
    output wire booth_add_en,
    output wire booth_sub_en,
    output wire booth_shift_en,
    output wire booth_count_en,
    output wire divider_load,
    output wire divider_add_en,
    output wire divider_sub_en,
    output wire divider_shift_en,
    output wire divider_count_en,
    output wire divider_final_add,
    output wire alu_done
);

    // ====== One-hot state encoding ======
    localparam IDLE           = 19'b0000000000000000001;
    localparam LOAD           = 19'b0000000000000000010;
    localparam ADD_EXEC       = 19'b0000000000000000100;
    localparam SUB_EXEC       = 19'b0000000000000001000;
    localparam MUL_LOAD       = 19'b0000000000000010000;
    localparam MUL_CHECK      = 19'b0000000000000100000;
    localparam MUL_ADD        = 19'b0000000000001000000;
    localparam MUL_SUB        = 19'b0000000000010000000;
    localparam MUL_SHIFT      = 19'b0000000000100000000;
    localparam MUL_COUNT      = 19'b0000000001000000000;
    localparam MUL_DONE       = 19'b0000000010000000000;
    localparam DIV_LOAD       = 19'b0000000100000000000;
    localparam DIV_SHIFT      = 19'b0000001000000000000;
    localparam DIV_OP         = 19'b0000010000000000000;
    localparam DIV_COUNT      = 19'b0000100000000000000;
    localparam DIV_FINAL_CORR = 19'b0001000000000000000;
    localparam DIV_DONE       = 19'b0010000000000000000;
    localparam DONE           = 19'b0100000000000000000;

    wire [18:0] current_state;
    wire [18:0] next_state;

    // ====== State register (structural, like before) ======
    register #(19) state_reg (
        .clk(clk),
        .d(next_state),
        .q(current_state)
    );

    // ====== Next-State Logic ======
    assign next_state = (reset) ? IDLE :
                        (current_state == IDLE)         ? (start ? LOAD : IDLE) :
                        (current_state == LOAD)         ? 
                            (op_code == 2'b00 ? ADD_EXEC :
                             op_code == 2'b01 ? SUB_EXEC :
                             op_code == 2'b10 ? MUL_LOAD :
                             DIV_LOAD) :
                        (current_state == ADD_EXEC)      ? DONE :
                        (current_state == SUB_EXEC)      ? DONE :
                        (current_state == MUL_LOAD)      ? MUL_CHECK :
                        (current_state == MUL_CHECK)     ? 
                            (booth_bits == 2'b01 ? MUL_ADD :
                             booth_bits == 2'b10 ? MUL_SUB :
                             MUL_SHIFT) :
                        (current_state == MUL_ADD)       ? MUL_SHIFT :
                        (current_state == MUL_SUB)       ? MUL_SHIFT :
                        (current_state == MUL_SHIFT)     ? MUL_COUNT :
                        (current_state == MUL_COUNT)     ? (booth_counter_done ? MUL_DONE : MUL_CHECK) :
                        (current_state == MUL_DONE)      ? DONE :
                        (current_state == DIV_LOAD)      ? DIV_SHIFT :
                        (current_state == DIV_SHIFT)     ? DIV_OP :
                        (current_state == DIV_OP)        ? DIV_COUNT :
                        (current_state == DIV_COUNT)     ? (divider_counter_done ? DIV_FINAL_CORR : DIV_SHIFT) :
                        (current_state == DIV_FINAL_CORR)? DIV_DONE :
                        (current_state == DIV_DONE)      ? DONE :
                        (current_state == DONE)          ? IDLE :
                        IDLE; // fallback

    // ====== Output Logic ======

    assign adder_en          = (current_state == ADD_EXEC);
    assign subtractor_en     = (current_state == SUB_EXEC);

    // Booth Datapath Control
    assign booth_load        = (current_state == MUL_LOAD);
    assign booth_add_en      = (current_state == MUL_ADD);
    assign booth_sub_en      = (current_state == MUL_SUB);
    assign booth_shift_en    = (current_state == MUL_SHIFT);
    assign booth_count_en    = (current_state == MUL_COUNT);

    // Divider Datapath Control
    assign divider_load      = (current_state == DIV_LOAD);
    assign divider_shift_en  = (current_state == DIV_SHIFT);
    assign divider_add_en    = (current_state == DIV_OP) && (divider_sign_R == 1'b1); // if R negative, add back
    assign divider_sub_en    = (current_state == DIV_OP) && (divider_sign_R == 1'b0); // if R positive, subtract
    assign divider_count_en  = (current_state == DIV_COUNT);
    assign divider_final_add = (current_state == DIV_FINAL_CORR);

    // ALU done signal
    assign alu_done = (current_state == DONE);

endmodule




