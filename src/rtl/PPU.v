module PPU (
    input       [31:0]              data_in,
    input       [3:0]               scaling_factor,
    input                           relu_en,
    output      [7:0]               data_out
);

    wire signed [31:0]    data_tmp0     = (relu_en & data_in[31]) ? (32'sd0) : (data_in);
    wire signed [31:0]    bias          = (data_tmp0[31]) ? ( (32'sd1 << scaling_factor) - 1 ) : 32'sd0;
    wire signed [31:0]    data_tmp1     = data_tmp0 + bias;
    wire signed [31:0]    data_tmp2     = (data_tmp1 >>> scaling_factor);
    wire signed [31:0]    data_tmp3     =  data_tmp0[31] ? (data_tmp2) : (data_tmp2 + data_tmp1[scaling_factor-1]);

    reg  signed [ 7:0]    data_tmp4;

    always@(*)begin
        if(data_tmp3 < (-128))      data_tmp4 = 8'd0;                               // after +128 clamp to 0
        else if (data_tmp3 > (127)) data_tmp4 = 8'd255;                             // after +128 clamp to 255
        else                        data_tmp4 = {~data_tmp3[7], data_tmp3[6:0]};    // [-127 127] -> +128
    end

    assign data_out = data_tmp4;

endmodule

