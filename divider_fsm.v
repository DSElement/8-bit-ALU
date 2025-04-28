module divider_fsm (
    input wire clk,
    input wire reset,
    input wire start,
    input wire sign_R,  // sign of remainder R (R[7])
    input wire done,    // counter says 7 cycles completed
    output wire load,
    output wire shift_en,
    output wire add_en,
    output wire sub_en,
    output wire count_en,
    output wire final_add,
    output wire divider_done
);

    // State Encoding (One-hot)
    localparam IDLE          = 7'b0000001;
    localparam LOAD          = 7'b0000010;
    localparam SHIFT         = 7'b0000100;
    localparam OPERATION     = 7'b0001000;
    localparam COUNT         = 7'b0010000;
    localparam FINAL_CORRECT = 7'b0100000;
    localparam DONE          = 7'b1000000;

    wire [6:0] current_state;
    wire [6:0] next_state;

    // State register (same style as before, structural)
    register #(7) state_reg (
        .clk(clk),
        .d(next_state),
        .q(current_state)
    );

    // Next-state logic
    assign next_state = (reset)               ? IDLE :
                        (current_state == IDLE)          ? (start ? LOAD : IDLE) :
                        (current_state == LOAD)          ? SHIFT :
                        (current_state == SHIFT)         ? OPERATION :
                        (current_state == OPERATION)     ? COUNT :
                        (current_state == COUNT)         ? (done ? FINAL_CORRECT : SHIFT) :
                        (current_state == FINAL_CORRECT) ? DONE :
                        (current_state == DONE)          ? IDLE :
                        IDLE; // default fallback

    // Output logic
    assign load        = (current_state == LOAD);
    assign shift_en    = (current_state == SHIFT);
    assign sub_en      = (current_state == OPERATION) && (sign_R == 0); // If R >= 0, do SUB
    assign add_en      = (current_state == OPERATION) && (sign_R == 1); // If R < 0, do ADD
    assign count_en    = (current_state == COUNT);
    assign final_add   = (current_state == FINAL_CORRECT);
    assign divider_done = (current_state == DONE);

endmodule

`timescale 1ns / 1ps

module divider_fsm_tb;

    // Inputs
    reg clk;
    reg reset;
    reg start;
    reg sign_R;  // sign of R (R[7])
    reg done;    // counter done

    // Outputs
    wire load;
    wire shift_en;
    wire add_en;
    wire sub_en;
    wire count_en;
    wire final_add;
    wire divider_done;

    // Instantiate the FSM
    divider_fsm uut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .sign_R(sign_R),
        .done(done),
        .load(load),
        .shift_en(shift_en),
        .add_en(add_en),
        .sub_en(sub_en),
        .count_en(count_en),
        .final_add(final_add),
        .divider_done(divider_done)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns clock
    end

    // Test sequence
    initial begin
        // Initialize
        reset = 1;
        start = 0;
        sign_R = 0;
        done = 0;

        #20;
        reset = 0;

        // Start division
        #10;
        start = 1;
        #10;
        start = 0; // pulse

        // After LOAD, FSM should move to SHIFT
        // Simulate different signs for R during operation

        // 1st iteration: R positive (do SUB)
        #50;
        sign_R = 0; // positive R
        #50;

        // 2nd iteration: R negative (do ADD)
        sign_R = 1; // negative R
        #50;

        // 3rd iteration: R positive again
        sign_R = 0;
        #50;

        // Set done=1 to finish after a few iterations
        #50;
        done = 1;

        // Let FSM reach FINAL_CORRECT and DONE
        #100;

        $stop;
    end

    // Monitor important stuff
    initial begin
        $monitor("TIME=%0t | STATE=%b | start=%b sign_R=%b done=%b || load=%b shift_en=%b add_en=%b sub_en=%b count_en=%b final_add=%b divider_done=%b",
            $time,
            uut.current_state,
            start,
            sign_R,
            done,
            load,
            shift_en,
            add_en,
            sub_en,
            count_en,
            final_add,
            divider_done
        );
    end

endmodule

