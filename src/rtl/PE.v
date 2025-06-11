`include "define.svh"

module PE (
    input                           clk,
    input                           rst,
    input                           PE_en,
    input [`CONFIG_SIZE-1:0]        i_config,
    input [`DATA_BITS-1:0]          ifmap,
    input [`DATA_BITS-1:0]          filter,
    input [`DATA_BITS-1:0]          ipsum,
    input                           ifmap_valid,
    input                           filter_valid,
    input                           ipsum_valid,
    input                           opsum_ready,
    output reg [`DATA_BITS-1:0]     opsum,
    output reg                      ifmap_ready,
    output reg                      filter_ready,
    output reg                      ipsum_ready,
    output reg                      opsum_valid
);

    reg           [ 1:0]            config_p;                       // 0~3
    reg           [ 7:0]            config_F;                       // 0~255
    reg           [ 1:0]            config_q;                       // 0~3
    reg signed    [ 7:0]            ifmap_spad[0:3][0:2];           // q S      signed  8 bit
    reg signed    [ 7:0]            filter_spad[0:3][0:2][0:3];     // q S p    signed  8 bit
    reg signed    [`DATA_BITS-1:0]  psum_spad[0:3];                 // p        signed 32 bit
    reg           [ 1:0]            q_cnt, p_cnt, s_cnt;
    reg           [ 7:0]            f_cnt;
    reg signed    [ 7:0]            mul_in0, mul_in1;
    reg signed    [31:0]            add_in0, add_in1;
    reg signed    [15:0]            mul_out_16;
    reg signed    [31:0]            add_out_32;

    localparam  IDLE        =   3'd0;
    localparam  READ_W      =   3'd1;
    localparam  READ_IF3    =   3'd2;
    localparam  READ_IP     =   3'd3;
    localparam  CAL_MUL     =   3'd4;
    localparam  READ_IF1    =   3'd5;
    localparam  WRITE_OP    =   3'd6;

    reg [2:0]   CS, NS;

    always@(posedge clk or posedge rst)
        CS <= rst ?  IDLE : NS;

    always@(*) begin
        case(CS)
            IDLE:       NS = READ_W;
            READ_W:     NS = (s_cnt==2'd2 && p_cnt==config_p && filter_valid)           ?   READ_IF3    :   READ_W;
            READ_IF3:   NS = (s_cnt==2'd2 && ifmap_valid)                               ?   READ_IP     :   READ_IF3;
            READ_IP:    NS = (p_cnt==config_p && ipsum_valid)                           ?   CAL_MUL     :   READ_IP;
            CAL_MUL:    NS = ((s_cnt==2'd2) && (q_cnt==config_q) && (p_cnt==config_p))  ?   WRITE_OP    :   CAL_MUL;
            READ_IF1:   NS = (ifmap_valid)                                              ?   READ_IP     :   READ_IF1;
            WRITE_OP:   if(opsum_ready && (p_cnt==config_p)) begin
                            NS = (f_cnt==config_F) ?  IDLE : READ_IF1;
                        end else begin
                            NS = WRITE_OP;
                        end
            default:    NS = IDLE;
        endcase
    end

    always@(*) begin
        opsum           = psum_spad[p_cnt];
        ifmap_ready     = (CS==READ_IF3 || CS==READ_IF1);
        filter_ready    = (CS==READ_W);
        ipsum_ready     = (CS==READ_IP);
        opsum_valid     = (CS==WRITE_OP);
        mul_in0         = ifmap_spad[q_cnt][s_cnt];
        mul_in1         = filter_spad[q_cnt][s_cnt][p_cnt];
        mul_out_16      = mul_in0 * mul_in1;
        add_in0         = (CS==CAL_MUL) ? {{16{mul_out_16[15]}},mul_out_16[15:0]} : ipsum;
        add_in1         = psum_spad[p_cnt];
        add_out_32      = add_in0 + add_in1;
    end

    integer i,j,k,qq,pp;

    always@(posedge clk or posedge rst) begin
        if(rst)begin
            config_p    <= 2'd0;
            config_q    <= 2'd0;
            config_F    <= 8'd0;
        end else begin
            if(PE_en) begin
                config_p    <= i_config[`CONFIG_SIZE-1 -: 2];   // [11:10]
                config_q    <= i_config[`CONFIG_SIZE-3 -: 2];   // [ 9: 8]
                config_F    <= i_config[`CONFIG_SIZE-5 -: 8];   // [ 7: 0]
            end
        end
    end

    always@(posedge clk or posedge rst) begin
        if(rst)begin
            q_cnt       <= 2'd0;
            p_cnt       <= 2'd0;
            s_cnt       <= 2'd0;
            f_cnt       <= 8'd0;

            for(i=0;i<4;i=i+1)
                for(j=0;j<3;j=j+1)
                    ifmap_spad[i][j] <= 8'h00;

            for(i=0;i<4;i=i+1)
                for(j=0;j<3;j=j+1)
                    for(k=0;k<4;k=k+1)
                        filter_spad[i][j][k] <= 8'h00;

            for(i=0;i<4;i=i+1)
                psum_spad[i] <= `DATA_BITS'd0;
        end else begin
            case(CS)
                IDLE: begin
                    q_cnt   <= 2'd0;
                    p_cnt   <= 2'd0;
                    s_cnt   <= 2'd0;
                    f_cnt   <= 8'd0;

                    for(i=0;i<4;i=i+1)
                        for(j=0;j<3;j=j+1)
                            ifmap_spad[i][j] <= 8'h00;

                    for(i=0;i<4;i=i+1)
                        for(j=0;j<3;j=j+1)
                            for(k=0;k<4;k=k+1)
                                filter_spad[i][j][k] <= 8'h00;

                    for(i=0;i<4;i=i+1)
                        psum_spad[i] <= `DATA_BITS'd0;
                end

                READ_W:begin
                    if(filter_valid) begin
                        for(qq=0;qq<4;qq=qq+1)
                            filter_spad[qq][s_cnt][p_cnt] <= filter[(qq<<3)+:8];
                        if(s_cnt==2'd2)begin
                            s_cnt <= 2'd0;
                            p_cnt <= (p_cnt==config_p ? 2'd0 : p_cnt + 2'd1);
                        end else begin
                            s_cnt <= s_cnt + 2'd1;
                        end
                    end
                end

                READ_IF3:begin
                    if(ifmap_valid) begin
                        for(qq=0;qq<4;qq=qq+1)
                            ifmap_spad[qq][s_cnt] <= (ifmap[(qq<<3)+:8] ^ 8'b1000_0000);
                        s_cnt <= (s_cnt==2'd2) ? (2'd0) : (s_cnt + 2'd1);
                    end
                end

                READ_IP:begin
                    // add_in0 = ipsum
                    // add_in1 = psum_spad[p_cnt]
                    if(ipsum_valid)begin
                        psum_spad[p_cnt]    <= add_out_32;
                        p_cnt               <= (p_cnt==config_p ? 2'd0 : p_cnt + 2'd1);
                    end
                end

                CAL_MUL:begin
                    // mul_in0 = ifmap_spad[q_cnt][s_cnt]
                    // mul_in1 = filter_spad[q_cnt][s_cnt][p_cnt]
                    // add_in0 = mul_out_16
                    // add_in1 = psum_spad[p_cnt]
                    psum_spad[p_cnt]    <= add_out_32;
                    if(s_cnt==2'd2)begin
                        s_cnt <= 2'd0;
                        if(q_cnt==config_q)begin
                            q_cnt <= 2'd0;
                            p_cnt <= (p_cnt==config_p) ? (2'd0) : (p_cnt + 2'd1);
                        end else begin
                            q_cnt <= q_cnt + 2'd1;
                        end
                    end else begin
                        s_cnt <= s_cnt + 2'd1;
                    end
                end

                WRITE_OP:begin
                    if(opsum_ready)begin
                        p_cnt <= (p_cnt==config_p) ? (2'd0) : (p_cnt + 2'd1);
                    end
                end

                READ_IF1:begin
                    if(ifmap_valid) begin
                        for(qq=0;qq<4;qq=qq+1)begin
                            ifmap_spad[qq][0] <= ifmap_spad[qq][1];
                            ifmap_spad[qq][1] <= ifmap_spad[qq][2];
                            ifmap_spad[qq][2] <= (ifmap[(qq<<3)+:8] ^ 8'b1000_0000);
                        end
                        f_cnt <= f_cnt + 8'd1;
                    end
                    for(pp=0;pp<4;pp=pp+1)
                        psum_spad[pp] <= `DATA_BITS'd0;
                end
            endcase
        end
    end

endmodule
