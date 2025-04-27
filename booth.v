module booth (
    input wire clk,
    input wire reset,
    input wire load,      // signal to load multiplicand and multiplier
    input wire shift_en,  // signal to shift
    input wire add_en,    // signal to enable add/sub
    input wire sub_en,    // signal to enable sub
    input wire count_en,  // signal to enable counter
    input wire [7:0] multiplicand,
    input wire [7:0] multiplier,
    output wire [15:0] product,
    output wire done,
    output wire [16:0] reg_data  // <-- NEW output
);

    wire [16:0] internal_reg_data;
    wire [16:0] shifted_data;
    wire [7:0] addsub_result;
    wire [2:0] count;

    // Splitting reg_data into fields
    wire [7:0] A = internal_reg_data[16:9];
    wire [7:0] Q = internal_reg_data[8:1];
    wire Qm1 = internal_reg_data[0];

    // Load multiplicand and multiplier
    wire [16:0] load_value = {8'b0, multiplier, 1'b0};

    // Parallel adder/subtractor
    add_sub #(8) addsub_inst (
        .a(A),
        .b(multiplicand),
        .sub(sub_en),
        .sum(addsub_result)
    );

    // Main working register (A, Q, Q-1)
    wire [16:0] next_reg_data;

    assign next_reg_data = reset ? 17'b0 :
                       load ? load_value :
                       add_en ? {addsub_result, internal_reg_data[8:0]} :
                       sub_en ? {addsub_result, internal_reg_data[8:0]} :
		       //sub_en ? {addsub_result, 9'b0} :
                       shift_en ? shifted_data :
                       internal_reg_data;


    register #(17) reg_AQ (
        .clk(clk),
        .d(next_reg_data),
        .q(internal_reg_data)
    );

    // Right arithmetic shifter
    shifter #(17) shifter_inst (
        .in(internal_reg_data),
	.direction(1'b0), // right shift for Booth
        .out(shifted_data)
    );

    // Counter
    counter #(3) count_inst (
        .clk(clk),
        .reset(reset),
        .enable(count_en),
        .count(count)
    );

    //assign shifted_data = {internal_reg_data[16], internal_reg_data[16:1]};

    assign done = (count == 3'b111);

    assign product = internal_reg_data[16:1];

    // Connect internal reg_data to output
    assign reg_data = internal_reg_data;

endmodule


/*`timescale 1ns/1ps

module booth_tb;

    reg clk;
    reg reset;
    reg load;
    reg shift_en;
    reg add_en;
    reg sub_en;
    reg count_en;
    reg [7:0] multiplicand;
    reg [7:0] multiplier;
    wire [15:0] product;
    wire done;
    wire [16:0] reg_data; // observe internal reg if needed

    booth DUT (
        .clk(clk),
        .reset(reset),
        .load(load),
        .shift_en(shift_en),
        .add_en(add_en),
        .sub_en(sub_en),
        .count_en(count_en),
        .multiplicand(multiplicand),
        .multiplier(multiplier),
        .product(product),
        .done(done),
        .reg_data(reg_data)
    );

    // Clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns clock
    end

    // Test sequence
    initial begin
        //$display("Time | A | B | Product | reg_data | done");
        //$monitor("%4t | %d | %d | %d | %b | %b", $time, multiplicand, multiplier, product, reg_data, done);
	$monitor("%4t | %d * %d = %d | A=%b Q=%b Q-1=%b | %b", 
        $time, multiplicand, multiplier, product, 
        reg_data[16:9], reg_data[8:1], reg_data[0], 
        done);

        // Reset
        reset = 1; load = 0; shift_en = 0; add_en = 0; sub_en = 0; count_en = 0;
        multiplicand = 0; multiplier = 0;
        #20;
        reset = 0;

        // ==============
        // Test:  5 * 3
        // ==============
        multiplicand = 8'b11111011;
        multiplier   = 8'b00000011;

        // Step 1: Load
        load = 1;
        #10;
        load = 0;

        // Booth Algorithm steps
        repeat (8) begin
            case ({reg_data[1], reg_data[0]}) // {Q0, Q-1}
                2'b01: begin
                    add_en = 1;
                    #10;
                    add_en = 0;
                end
                2'b10: begin
                    sub_en = 1;
                    #10;
                    sub_en = 0;
                end
                default: begin
                    // No operation
                    #10;
                end
            endcase

	    #40
            // Shift
            shift_en = 1;
            count_en = 1;
            #10;
            shift_en = 0;
            count_en = 0;
        end

        // Wait few cycles
        #50;

        $stop;
    end

endmodule*/
