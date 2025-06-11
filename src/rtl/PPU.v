module PPU (
    input       [31:0]              data_in,
    input       [3:0]               scaling_factor, // 8 or 6
    input                           relu_en,
    output      [7:0]               data_out
);

    wire signed [31:0]    data_tmp0     = (relu_en & data_in[31]) ? (32'sd0) : (data_in);
    wire signed [ 8:0]    bias          = (data_tmp0[31]) ? ( (9'sd1 << scaling_factor) - 9'sd1 ) : 9'sd0;
    wire signed [31:0]    data_tmp1     = data_tmp0 + bias;
    wire                  carry         = (~data_tmp1[31] & data_tmp1[scaling_factor-1]);
    wire signed [31:0]    data_tmp2     = (data_tmp1 >>> scaling_factor) + carry;
    reg  signed [ 7:0]    data_tmp3;

    always@(*)begin
        if(data_tmp2 < (-128))      data_tmp3 = 8'd0;                               // after +128 clamp to 0
        else if (data_tmp2 > (127)) data_tmp3 = 8'd255;                             // after +128 clamp to 255
        else                        data_tmp3 = {~data_tmp2[7], data_tmp2[6:0]};    // [-127 127] -> +128
    end

    assign data_out = data_tmp3;

endmodule

