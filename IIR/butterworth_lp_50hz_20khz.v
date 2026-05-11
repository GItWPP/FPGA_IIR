`timescale 1ns / 1ps

module iir_lp_50hz_20khz 
(
    input  wire               sys_clk,
    input  wire               sys_rst_n,

    input  wire signed [15:0] din,
    input  wire               din_valid,

    output wire signed [15:0] dout,
    output wire               dout_valid
);

    localparam integer SAMPLE_WIDTH = 48;
    localparam integer FRAC         = 30;

    wire signed [SAMPLE_WIDTH-1:0] x_q30;
    assign x_q30 = {{(SAMPLE_WIDTH-16){din[15]}}, din} <<< FRAC;

    wire signed [SAMPLE_WIDTH-1:0] y1_q30;
    wire signed [SAMPLE_WIDTH-1:0] y2_q30;
    wire v1;

    biquad_iir_q30 #(
        .B0( 32'sd65837),
        .B1( 32'sd131673),
        .B2( 32'sd65837),
        .A1(-32'sd2134389055),
        .A2( 32'sd1060910578)
    ) u_sos1 (
        .sys_clk        (sys_clk),
        .sys_rst_n      (sys_rst_n),
        .sample_in  	(x_q30),
        .valid_in   	(din_valid),
        .sample_out 	(y1_q30),
        .valid_out  	(v1)
    );

     biquad_iir_q30 #(
        .B0( 32'sd65285),
        .B1( 32'sd130570),
        .B2( 32'sd65285),
        .A1(-32'sd2116504703),
        .A2( 32'sd1043024019)
    ) u_sos2 (
        .sys_clk        (sys_clk),
        .sys_rst_n      (sys_rst_n),
        .sample_in  	(y1_q30),
        .valid_in   	(v1),
        .sample_out 	(y2_q30),
        .valid_out  	(v2)
    ); 

    assign dout       = q30_to_s16(y2_q30);
    assign dout_valid = v2;

    function signed [15:0] q30_to_s16;
        input signed [SAMPLE_WIDTH-1:0] x;
        reg   signed [SAMPLE_WIDTH-1:0] x_int;
        begin
            x_int = x >>> FRAC;

            if (x_int > 48'sd32767)
                q30_to_s16 = 16'sd32767;
            else if (x_int < -48'sd32768)
                q30_to_s16 = -16'sd32768;
            else
                q30_to_s16 = x_int[15:0];
        end
    endfunction

endmodule