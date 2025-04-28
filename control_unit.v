module control_unit (
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

endmodule

