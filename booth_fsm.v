module booth_fsm (
    input wire clk,
    input wire reset,
    input wire start,
    input wire [1:0] booth_bits, // {Q0, Q-1}
    input wire done,
    output wire load,
    output wire shift_en,
    output wire add_en,
    output wire sub_en,
    output wire count_en,
    output wire booth_done
);

    // State Encoding (One-hot)
    localparam IDLE  = 7'b0000001;
    localparam LOAD  = 7'b0000010;
    localparam CHECK = 7'b0000100;
    localparam ADD   = 7'b0001000;
    localparam SUB   = 7'b0010000;
    localparam SHIFT = 7'b0100000;
    localparam DONE  = 7'b1000000;

    wire [6:0] current_state;
    wire [6:0] next_state;

    // State register (using your register module)
    register #(7) state_reg (
        .clk(clk),
        .d(next_state),
        .q(current_state)
    );

    // Next-state logic (purely combinational)
    assign next_state = (reset)               ? IDLE :
                        (current_state == IDLE)  ? (start ? LOAD : IDLE) :
                        (current_state == LOAD)  ? CHECK :
                        (current_state == CHECK) ? 
                            (booth_bits == 2'b01 ? ADD :
                             booth_bits == 2'b10 ? SUB :
                             SHIFT) :
                        (current_state == ADD)   ? SHIFT :
                        (current_state == SUB)   ? SHIFT :
                        (current_state == SHIFT) ? (done ? DONE : CHECK) :
                        (current_state == DONE)  ? IDLE :
                        IDLE; // default fallback

    // Output logic (purely combinational)
    assign load      = (current_state == LOAD);
    assign add_en    = (current_state == ADD);
    assign sub_en    = (current_state == SUB);
    assign shift_en  = (current_state == SHIFT);
    assign count_en  = (current_state == SHIFT); // increment counter after every shift
    assign booth_done = (current_state == DONE);

endmodule

/*`timescale 1ns / 1ps

module booth_fsm_tb;

    // Inputs
    reg clk;
    reg reset;
    reg start;
    reg [1:0] booth_bits;
    reg done;

    // Outputs
    wire load;
    wire shift_en;
    wire add_en;
    wire sub_en;
    wire count_en;
    wire booth_done;

    // Instantiate the FSM
    booth_fsm uut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .booth_bits(booth_bits),
        .done(done),
        .load(load),
        .shift_en(shift_en),
        .add_en(add_en),
        .sub_en(sub_en),
        .count_en(count_en),
        .booth_done(booth_done)
    );

    // Clock generator
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns period
    end

// Monitor everything important
    initial begin
        $monitor("TIME=%0t | STATE=%b | start=%b booth_bits=%b done=%b || load=%b add_en=%b sub_en=%b shift_en=%b count_en=%b booth_done=%b", 
            $time,
            uut.current_state,
            start,
            booth_bits,
            done,
            load,
            add_en,
            sub_en,
            shift_en,
            count_en,
            booth_done
        );
    end

    // Test sequence
    initial begin
        // Initialize
        reset = 1;
        start = 0;
        booth_bits = 2'b00;
        done = 0;

        #20;
        reset = 0;

        // Start multiplication
        #10;
        start = 1;
        #10;
        start = 0; // pulse

        // FSM should now move to LOAD then CHECK

        // Simulate booth_bits changing during CHECK
        // 2'b01 --> ADD
        #50;
        booth_bits = 2'b01;
        #50;
        booth_bits = 2'b00; // after ADD/SHIFT, return to CHECK
        
        // 2'b10 --> SUB
        #50;
        booth_bits = 2'b10;
        #50;
        booth_bits = 2'b00;

        // 2'b00 --> SHIFT directly
        #50;
        booth_bits = 2'b00;

        // Indicate done to FSM after some shifts
        #50;
        done = 1;

        #50;
        done = 0;

        // Let FSM go to DONE and return to IDLE
        #100;

        $stop;
    end

endmodule*/

