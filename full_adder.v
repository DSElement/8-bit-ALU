module full_adder (
    input wire a,
    input wire b,
    input wire cin,
    output wire s,
    output wire cout
);

    wire w1, w2, w3;

    xor (w1, a, b);
    xor (s, w1, cin);
    and (w2, a, b);
    and (w3, w1, cin);
    or  (cout, w2, w3);

endmodule