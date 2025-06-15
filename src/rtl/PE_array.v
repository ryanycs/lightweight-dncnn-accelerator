// `include "PE.v"
`include "define.svh"

module PE_array #(
    parameter NUMS_PE_ROW   = `NUMS_PE_ROW,
    parameter NUMS_PE_COL   = `NUMS_PE_COL,
    parameter XID_BITS      = `XID_BITS,
    parameter YID_BITS      = `YID_BITS,
    parameter DATA_SIZE     = `DATA_BITS,
    parameter CONFIG_SIZE   = `CONFIG_SIZE
)(
    input                                   clk,
    input                                   rst,
    input                                   SET_XID,
    input [XID_BITS-1:0]                    ifmap_XID_scan_in,
    input [XID_BITS-1:0]                    filter_XID_scan_in,
    input [XID_BITS-1:0]                    ipsum_XID_scan_in,
    input [XID_BITS-1:0]                    opsum_XID_scan_in,
    input                                   SET_YID,
    input [YID_BITS-1:0]                    ifmap_YID_scan_in,
    input [YID_BITS-1:0]                    filter_YID_scan_in,
    input [YID_BITS-1:0]                    ipsum_YID_scan_in,
    input [YID_BITS-1:0]                    opsum_YID_scan_in,
    input                                   SET_LN,
    input [NUMS_PE_ROW-2:0]                 LN_config_in,
    input [NUMS_PE_ROW * NUMS_PE_COL-1:0]   PE_en,
    input [CONFIG_SIZE-1:0]                 PE_config,
    input [XID_BITS-1:0]                    ifmap_tag_X,
    input [YID_BITS-1:0]                    ifmap_tag_Y,
    input [XID_BITS-1:0]                    filter_tag_X,
    input [YID_BITS-1:0]                    filter_tag_Y,
    input [XID_BITS-1:0]                    ipsum_tag_X,
    input [YID_BITS-1:0]                    ipsum_tag_Y,
    input [XID_BITS-1:0]                    opsum_tag_X,
    input [YID_BITS-1:0]                    opsum_tag_Y,
    input                                   GLB_ifmap_valid,
    output reg                              GLB_ifmap_ready,
    input                                   GLB_filter_valid,
    output reg                              GLB_filter_ready,
    input                                   GLB_ipsum_valid,
    output reg                              GLB_ipsum_ready,
    input       [DATA_SIZE-1:0]             GLB_data_in,
    output reg                              GLB_opsum_valid,
    input                                   GLB_opsum_ready,
    output reg  [DATA_SIZE-1:0]             GLB_data_out,

    input                                   op_get_done,
    input                                   op_pass_done,
    input                                   PE_reset,

    input [2:0]                             opsum_e_cnt,
    input [1:0]                             opsum_t_cnt,
    input [2:0]                             layer_info
);

    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] RDW    = 3'd1;
    localparam [2:0] RDIF3  = 3'd2;
    localparam [2:0] RDIP   = 3'd3;
    localparam [2:0] WROP   = 3'd4;
    localparam [2:0] RDIF1  = 3'd5;

    reg [2:0]             S ,NS;

    // LN
    reg [NUMS_PE_ROW-2:0] LN_config_reg;

    // Tag register
    reg [XID_BITS-1:0]    ifmap_tx      [0:NUMS_PE_ROW * NUMS_PE_COL-1];
    reg [XID_BITS-1:0]    filter_tx     [0:NUMS_PE_ROW * NUMS_PE_COL-1];
    reg [XID_BITS-1:0]    ipsum_tx      [0:NUMS_PE_ROW * NUMS_PE_COL-1];
    reg [XID_BITS-1:0]    opsum_tx      [0:NUMS_PE_ROW * NUMS_PE_COL-1];
    reg [YID_BITS-1:0]    ifmap_ty      [0:NUMS_PE_ROW-1];
    reg [YID_BITS-1:0]    filter_ty     [0:NUMS_PE_ROW-1];
    reg [YID_BITS-1:0]    ipsum_ty      [0:NUMS_PE_ROW-1];
    reg [YID_BITS-1:0]    opsum_ty      [0:NUMS_PE_ROW-1];

    // Tag wire
    reg [XID_BITS-1:0]    ifmap_tx_2d   [0:NUMS_PE_ROW-1][0:NUMS_PE_COL-1];
    reg [XID_BITS-1:0]    filter_tx_2d  [0:NUMS_PE_ROW-1][0:NUMS_PE_COL-1];
    reg [XID_BITS-1:0]    ipsum_tx_2d   [0:NUMS_PE_ROW-1][0:NUMS_PE_COL-1];
    reg [XID_BITS-1:0]    opsum_tx_2d   [0:NUMS_PE_ROW-1][0:NUMS_PE_COL-1];

    // PE interface
    reg [DATA_SIZE-1:0]   ipsum         [0:NUMS_PE_ROW-1][0:NUMS_PE_COL-1];
    wire[DATA_SIZE-1:0]   opsum         [0:NUMS_PE_ROW-1][0:NUMS_PE_COL-1];
    reg                   ifmap_valid   [0:NUMS_PE_ROW-1][0:NUMS_PE_COL-1];
    reg                   filter_valid  [0:NUMS_PE_ROW-1][0:NUMS_PE_COL-1];
    reg                   ipsum_valid   [0:NUMS_PE_ROW-1][0:NUMS_PE_COL-1];
    wire                  opsum_valid   [0:NUMS_PE_ROW-1][0:NUMS_PE_COL-1];
    reg                   opsum_ready   [0:NUMS_PE_ROW-1][0:NUMS_PE_COL-1];
    wire                  ifmap_ready   [0:NUMS_PE_ROW-1][0:NUMS_PE_COL-1];
    wire                  filter_ready  [0:NUMS_PE_ROW-1][0:NUMS_PE_COL-1];
    wire                  ipsum_ready   [0:NUMS_PE_ROW-1][0:NUMS_PE_COL-1];

    // Ready vector
    reg [NUMS_PE_ROW * NUMS_PE_COL-1:0] ipsum_ready_1d;
    reg [NUMS_PE_ROW * NUMS_PE_COL-1:0] ifmap_ready_1d;
    reg [NUMS_PE_ROW * NUMS_PE_COL-1:0] filter_ready_1d;

    // READ COUNT
    reg                     GLB_filter_valid_pre;
    reg                     GLB_ifmap_valid_pre;
    reg                     GLB_ipsum_valid_pre;

    // Output count
    reg [1:0]               out_p_cnt;
    reg [7:0]               out_F_cnt;
    reg [4:0]               out_et_cnt;

    integer i,j;

    // PE Array
    genvar y_idx, x_idx;
    generate
        for(y_idx=0; y_idx<NUMS_PE_ROW; y_idx=y_idx+1)begin: PE_ARRAY_Y
            for(x_idx=0; x_idx<NUMS_PE_COL; x_idx=x_idx+1)begin: PE_ARRAY_X
                PE PEU (
                    .clk           (clk),
                    .rst           (rst | PE_reset),
                    .PE_en         (PE_en[y_idx * NUMS_PE_COL + x_idx]),
                    .i_config      (PE_config),
                    .ifmap         (GLB_data_in),
                    .filter        (GLB_data_in),
                    .ipsum         (ipsum[y_idx][x_idx]),
                    .ifmap_valid   (ifmap_valid[y_idx][x_idx]),
                    .filter_valid  (filter_valid[y_idx][x_idx]),
                    .ipsum_valid   (ipsum_valid[y_idx][x_idx]),
                    .opsum_ready   (opsum_ready[y_idx][x_idx]),
                    .opsum         (opsum[y_idx][x_idx]),
                    .ifmap_ready   (ifmap_ready[y_idx][x_idx]),
                    .filter_ready  (filter_ready[y_idx][x_idx]),
                    .ipsum_ready   (ipsum_ready[y_idx][x_idx]),
                    .opsum_valid   (opsum_valid[y_idx][x_idx])
                );
            end
        end
    endgenerate

    // State Transition
    always@(posedge clk or posedge rst)begin
       S <= rst ? IDLE : NS;
    end

    // Next State
    always@(*) begin
        case(S)
            IDLE:       NS = RDW;
            RDW:        NS = (GLB_filter_valid_pre & (~GLB_filter_valid))   ?   RDIF3   :   RDW;
            RDIF3:      NS = (GLB_ifmap_valid_pre & (~GLB_ifmap_valid))     ?   RDIP    :   RDIF3;
            RDIP:       NS = (GLB_ipsum_valid_pre & (~GLB_ipsum_valid))     ?   WROP    :   RDIP;
            WROP:       if((op_get_done) & (GLB_opsum_ready)) begin  // 1 -> 0
                            NS = (op_pass_done) ? IDLE : RDIF1;
                        end else begin
                            NS = WROP;
                        end
            RDIF1:      NS = (GLB_ifmap_valid_pre & (~GLB_ifmap_valid))     ?   RDIP    :   RDIF1;
            default:    NS = IDLE;
        endcase
    end

    // LN Config
    always@(posedge clk or posedge rst)begin
        if(rst)begin
            LN_config_reg <= {(NUMS_PE_ROW-1){1'b0}};
        end else begin
            if(SET_LN)begin
                LN_config_reg <= LN_config_in;
            end
        end
    end

    // SET YID
    always@(posedge clk or posedge rst)begin
        if(rst)begin
            for(i=0; i<NUMS_PE_ROW; i=i+1)begin
                ifmap_ty[i]     <=  `YID_BITS'd0;
                filter_ty[i]    <=  `YID_BITS'd0;
                ipsum_ty[i]     <=  `YID_BITS'd0;
                opsum_ty[i]     <=  `YID_BITS'd0;
            end
        end else begin
            if(SET_YID)begin
                ifmap_ty[NUMS_PE_ROW-1]     <=  ifmap_YID_scan_in;
                filter_ty[NUMS_PE_ROW-1]    <=  filter_YID_scan_in;
                ipsum_ty[NUMS_PE_ROW-1]     <=  ipsum_YID_scan_in;
                opsum_ty[NUMS_PE_ROW-1]     <=  opsum_YID_scan_in;
                for(i=0;i<NUMS_PE_ROW-1;i=i+1)begin
                    ifmap_ty[i]     <=  ifmap_ty[i+1];
                    filter_ty[i]    <=  filter_ty[i+1];
                    ipsum_ty[i]     <=  ipsum_ty[i+1];
                    opsum_ty[i]     <=  opsum_ty[i+1];
                end
            end
        end
    end

    // SET XID
    always@(posedge clk or posedge rst)begin
        if(rst)begin
            for(i=0; i<NUMS_PE_ROW * NUMS_PE_COL; i=i+1)begin
                ifmap_tx[i]     <=  `XID_BITS'd0;
                filter_tx[i]    <=  `XID_BITS'd0;
                ipsum_tx[i]     <=  `XID_BITS'd0;
                opsum_tx[i]     <=  `XID_BITS'd0;
            end
        end else begin
            if(SET_XID)begin
                ifmap_tx[NUMS_PE_ROW * NUMS_PE_COL-1]     <=  ifmap_XID_scan_in;
                filter_tx[NUMS_PE_ROW * NUMS_PE_COL-1]    <=  filter_XID_scan_in;
                ipsum_tx[NUMS_PE_ROW * NUMS_PE_COL-1]     <=  ipsum_XID_scan_in;
                opsum_tx[NUMS_PE_ROW * NUMS_PE_COL-1]     <=  opsum_XID_scan_in;
                for(i=0; i<NUMS_PE_ROW * NUMS_PE_COL-1; i=i+1)begin
                    ifmap_tx[i]     <=  ifmap_tx[i+1];
                    filter_tx[i]    <=  filter_tx[i+1];
                    ipsum_tx[i]     <=  ipsum_tx[i+1];
                    opsum_tx[i]     <=  opsum_tx[i+1];
                end
            end
        end
    end

    // XID 2D
    always@(*) begin
        for(i=0; i<NUMS_PE_ROW; i=i+1)begin
            for(j=0; j<NUMS_PE_COL; j=j+1)begin
                ifmap_tx_2d[i][j]   = ifmap_tx[i*NUMS_PE_COL + j];
                filter_tx_2d[i][j]  = filter_tx[i*NUMS_PE_COL + j];
                ipsum_tx_2d[i][j]   = ipsum_tx[i*NUMS_PE_COL + j];
                opsum_tx_2d[i][j]   = opsum_tx[i*NUMS_PE_COL + j];
            end
        end
    end

    // Ready 2D to vector
    always@(*) begin
        for(i=0; i<NUMS_PE_ROW * NUMS_PE_COL; i=i+1)begin
            ipsum_ready_1d[i]  = ipsum_ready[i/NUMS_PE_COL][i%NUMS_PE_COL];
            ifmap_ready_1d[i]  = ifmap_ready[i/NUMS_PE_COL][i%NUMS_PE_COL];
            filter_ready_1d[i] = filter_ready[i/NUMS_PE_COL][i%NUMS_PE_COL];
        end
    end

    // PE ifmap valid, filter valid
    always@(*) begin
        for(i=0; i<NUMS_PE_ROW; i=i+1)begin
            for(j=0; j<NUMS_PE_COL; j=j+1)begin
                ifmap_valid[i][j]   = (ifmap_tx_2d[i][j]==ifmap_tag_X)   & (ifmap_ty[i]==ifmap_tag_Y)   & (GLB_ifmap_valid)  & (S==RDIF1 || S==RDIF3);
                filter_valid[i][j]  = (filter_tx_2d[i][j]==filter_tag_X) & (filter_ty[i]==filter_tag_Y) & (GLB_filter_valid) & (S==RDW);
            end
        end
    end

    // PE ipsum, ipsum valid
    always@(*) begin
        for(j=0; j<NUMS_PE_COL; j=j+1)begin
            ipsum[0][j]         = GLB_data_in;
            ipsum_valid[0][j]   = (ipsum_tx_2d[0][j]==ipsum_tag_X) && (ipsum_ty[0]==ipsum_tag_Y) && (GLB_ipsum_valid) && (S==RDIP);
        end
        for(i=1; i<NUMS_PE_ROW; i=i+1)begin
            for(j=0; j<NUMS_PE_COL; j=j+1)begin
                if(LN_config_reg[i-1])begin // connect to upper PE
                    ipsum[i][j]         = opsum[i-1][j];
                    ipsum_valid[i][j]   = opsum_valid[i-1][j];
                end else begin              // connect to GLB
                    ipsum[i][j]         = GLB_data_in;
                    ipsum_valid[i][j]   = (ipsum_tx_2d[i][j]==ipsum_tag_X) && (ipsum_ty[i]==ipsum_tag_Y) && (GLB_ipsum_valid) && (S==RDIP);
                end
            end
        end
    end

    // PE opsum ready
    always@(*) begin
        // inner rows
        for(i=0; i<NUMS_PE_ROW-1; i=i+1)begin
            for(j=0; j<NUMS_PE_COL; j=j+1)begin
                if(LN_config_reg[i])begin // connect to lower PE
                    opsum_ready[i][j] = ipsum_ready[i+1][j];
                end else begin
                    opsum_ready[i][j] = ((opsum_ty[i]==opsum_tag_Y) && (opsum_tx_2d[i][j]==opsum_tag_X) && GLB_opsum_ready);
                end
            end
        end
        // last row
        for(j=0; j<NUMS_PE_COL; j=j+1)begin
            opsum_ready[`NUMS_PE_ROW-1][j] = ((opsum_ty[`NUMS_PE_ROW-1]==opsum_tag_Y) && (opsum_tx_2d[`NUMS_PE_ROW-1][j]==opsum_tag_X) && GLB_opsum_ready);
        end
    end

    // in data
    always@(posedge clk or posedge rst)begin
        if(rst)begin
            GLB_filter_valid_pre    <= 1'b0;
            GLB_ifmap_valid_pre     <= 1'b0;
            GLB_ipsum_valid_pre     <= 1'b0;
        end else begin
            GLB_filter_valid_pre    <= GLB_filter_valid;
            GLB_ifmap_valid_pre     <= GLB_ifmap_valid;
            GLB_ipsum_valid_pre     <= GLB_ipsum_valid;
        end
    end

    // Ouput data
    always@(*) begin
        GLB_opsum_valid = 1'b0;
        GLB_data_out    = `DATA_BITS'd0;
        for(i=2; i<NUMS_PE_ROW; i=i+3)begin // 2 5 8 11
            for(j=0; j<NUMS_PE_COL; j=j+1)begin
                if((opsum_ty[i]==opsum_tag_Y) && (opsum_tx_2d[i][j]==opsum_tag_X))begin
                    GLB_opsum_valid = opsum_valid[i][j];
                    GLB_data_out    = opsum[i][j];
                end
            end
        end
        // case(layer_info)
        //     3'd0:begin
        //         GLB_opsum_valid = opsum_valid[{opsum_t_cnt, 1'b0} + opsum_t_cnt + 2][opsum_e_cnt];             // t*3,   e
        //         GLB_data_out    = opsum[{opsum_t_cnt, 1'b0} + opsum_t_cnt + 2][opsum_e_cnt];
        //     end
        //     3'd1,3'd2,3'd3:begin
        //         GLB_opsum_valid = opsum_valid[NUMS_PE_ROW-1][opsum_e_cnt+{opsum_t_cnt[0],opsum_t_cnt[0]}];     // 11,      t*3+e
        //         GLB_data_out    = opsum[NUMS_PE_ROW-1][opsum_e_cnt+{opsum_t_cnt[0],opsum_t_cnt[0]}];
        //     end
        //     default:begin
        //         GLB_opsum_valid = opsum_valid[NUMS_PE_ROW-1][opsum_e_cnt];                                     // 11,      e
        //         GLB_data_out    = opsum[NUMS_PE_ROW-1][opsum_e_cnt];
        //     end
        // endcase
    end

    // GLB signal
    always@(*) begin
        GLB_filter_ready    = (S==RDW)              && (|filter_ready_1d);
        GLB_ifmap_ready     = (S==RDIF1||S==RDIF3)  && (|ifmap_ready_1d);
        GLB_ipsum_ready     = (S==RDIP)             && (|ipsum_ready_1d);
    end

endmodule
