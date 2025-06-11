`include "define.svh"

module  Controller(
    input               clk,
    input               rst,
    // PS interface
    input   [1:0]       layer_info,
    input               layer_enable,
    input               pass_enable,
    output              pass_ready,
    output              pass_done,
    // BRAM PORT B interface
    output reg  [31:0]  bram_b_addr,
    output reg  [31:0]  bram_b_din,
    input       [31:0]  bram_b_dout,
    output              bram_b_en,
    output reg  [3:0]   bram_b_web
);

    localparam L0 = 2'b00, L13 = 2'b01, L4 = 2'b10;
    localparam LAYERIDLE     = 5'd0,  SETLN = 5'd1, SETXID = 5'd2, SETYID = 5'd3;
    localparam PASSIDLE      = 5'd4;
    localparam FEEDF_ADDR    = 5'd5,  FEEDFILTER    = 5'd6;
    localparam FEEDIF3_ADDR0 = 5'd7,  FEEDIF3_ADDR1 = 5'd8,  FEEDIF3    = 5'd9;
    localparam FEEDIP_ADDR0  = 5'd10, FEEDIP_ADDR1  = 5'd11, FEEDIPSUM  = 5'd12;
    localparam FEEDIF1_ADDR0 = 5'd13, FEEDIF1_ADDR1 = 5'd14, FEEDIF1    = 5'd15;
    localparam GETOPADDR     = 5'd16, GETOPSUM      = 5'd17;
    localparam PASSDONE      = 5'd18;

    // flip-flop
    reg  [4:0]  CS, NS;

    // Config =====================================================================================================
    reg  [1:0]  layer_info_reg;
    reg  [6:0]  xid_cnt;
    reg  [3:0]  yid_cnt;
    // Config =====================================================================================================

    integer     i, j;

    // PE array signals ===========================================================================================
    wire                                        SET_XID;
    wire                                        SET_YID;
    wire                                        SET_LN;
    wire [`NUMS_PE_ROW-2:0]                     LN_config_in;
    wire [`NUMS_PE_ROW * `NUMS_PE_COL-1:0]      PE_en;
    wire [`CONFIG_SIZE-1:0]                     PE_config;
    wire [`XID_BITS-1:0]                        ifmap_XID_scan_in;
    wire [`XID_BITS-1:0]                        filter_XID_scan_in;
    wire [`XID_BITS-1:0]                        ipsum_XID_scan_in;
    wire [`XID_BITS-1:0]                        opsum_XID_scan_in;
    wire [`YID_BITS-1:0]                        ifmap_YID_scan_in;
    wire [`YID_BITS-1:0]                        filter_YID_scan_in;
    wire [`YID_BITS-1:0]                        ipsum_YID_scan_in;
    wire [`YID_BITS-1:0]                        opsum_YID_scan_in;
    wire [`XID_BITS-1:0]                        ifmap_tag_X;
    wire [`YID_BITS-1:0]                        ifmap_tag_Y;
    wire [`XID_BITS-1:0]                        filter_tag_X;
    wire [`YID_BITS-1:0]                        filter_tag_Y;
    wire [`XID_BITS-1:0]                        ipsum_tag_X;
    wire [`YID_BITS-1:0]                        ipsum_tag_Y;
    wire [`XID_BITS-1:0]                        opsum_tag_X;
    wire [`YID_BITS-1:0]                        opsum_tag_Y;
    wire                                        GLB_ifmap_valid;
    wire                                        GLB_ifmap_ready;
    wire                                        GLB_filter_valid;
    wire                                        GLB_filter_ready;
    wire                                        GLB_ipsum_valid;
    wire                                        GLB_ipsum_ready;
    reg  [`DATA_SIZE-1:0]                       GLB_data_in;
    wire                                        GLB_opsum_valid;
    wire                                        GLB_opsum_ready;
    wire [`DATA_SIZE-1:0]                       GLB_data_out;
    // PE array signals ===========================================================================================

    // PPU signals ================================================================================================
    wire [3:0]                                  PPU_scaling_factor  = (layer_info_reg==L0) ? 4'd6 : 4'd8;
    wire                                        PPU_relu_en         = (layer_info_reg==L4) ? 1'b0 : 1'b1;
    wire [7:0]                                  PPU_data_out;
    // PPU signals ================================================================================================

    // ID LIST constant ===========================================================================================
    reg [2:0]   IF_XID[0:71], W_XID[0:71], IP_XID[0:71], OP_XID[0:71];
    reg [3:0]   IF_YID[0:11], W_YID[0:11], IP_YID[0:11], OP_YID[0:11];
    // ID LIST constant ===========================================================================================

    // mapping parameters lim =====================================================================================
    reg  [5:0]  m_lim;
    reg  [2:0]  e_lim;
    reg  [1:0]  p_lim, q_lim, r_lim, t_lim;
    reg  [2:0]  m_shift_value;
    // mapping parameters lim =====================================================================================

    // shape parameters lim (for pass ) ===========================================================================
    //                              LFIRST               LMID                LLAST
    reg  [2:0]  tile_M_cnt; //      0~3 (64/16)          0~7 (64/8)          0~0 (1/1)
    reg  [1:0]  tile_C_cnt; //      0~0 (1/1)            0~3 (64/16)         0~3 (64/16)
    reg  [6:0]  tile_E_cnt; //      0~41 +1 (256/6)      0~84 +1 (256/3)     0~41 +1 (256/6)
    //                              42...4               85...1              42...4
    reg  [2:0]  M_lim;
    reg  [1:0]  C_lim;
    reg  [6:0]  E_lim;
    wire        tile_M_done     = (tile_M_cnt == M_lim);
    wire        tile_C_done     = (tile_C_cnt == C_lim);
    wire        tile_E_done     = (tile_E_cnt == E_lim);

    wire [8:0]  tile_M_mul_pt   = (tile_M_cnt << m_shift_value);
    // shape parameters cnt (for pass) ============================================================================

    // feed weight ================================================================================================
    // (q) w -> h -> r -> p -> t
    // L0 : tag y = {ker_t_cnt, ker_h_cnt}
    // L13: tag y = {ker_r_cnt, ker_h_cnt}
    // L4:  tag y = {ker_r_cnt, ker_h_cnt}
    // L0 : tag x = 3'd0;
    // L13: tag x = {1'b0, ker_t_cnt}
    // L4:  tag x = 3'd0;
    //                              LFIRST  LMID    LLAST
    reg  [1:0]  ker_w_cnt;    //    0~2     0~2     0~2
    reg  [1:0]  ker_h_cnt;    //    0~2     0~2     0~2
    reg  [1:0]  ker_r_cnt;    //    0~0     0~3     0~3
    reg  [1:0]  ker_p_cnt;    //    0~3     0~3     0~0
    reg  [1:0]  ker_t_cnt;    //    0~3     0~1     0~0
    wire        ker_w_done      = (ker_w_cnt[1]);
    wire        ker_h_done      = (ker_h_cnt[1]);
    wire        ker_r_done      = (ker_r_cnt == r_lim);
    wire        ker_p_done      = (ker_p_cnt == p_lim);
    wire        ker_t_done      = (ker_t_cnt == t_lim);
    wire        ker_feed_done   = (ker_w_done & ker_h_done & ker_r_done & ker_p_done & ker_t_done & GLB_filter_ready);
    // feed weight ================================================================================================

    // feed ifmap =================================================================================================
    // (q) -> w -> h -> r
    // tag y = if_r_cnt
    // tag x = if_h_cnt
    //                              LFIRST  LMID    LLAST
    reg  [1:0]  if_w_cnt;     //    0~2     0~2     0~2
    reg  [2:0]  if_h_cnt;     //    0~7     0~4     0~7
    reg  [1:0]  if_r_cnt;     //    0~0     0~3     0~3
    reg  [1:0]  if_w_cnt_p1;  //    0~2     0~2     0~2
    reg  [2:0]  if_h_cnt_p1;  //    0~7     0~4     0~7
    reg  [1:0]  if_r_cnt_p1;  //    0~0     0~3     0~3
    wire [2:0]  if_h_lim        = e_lim + 3'd2;
    wire        if_w_done       = (if_w_cnt[1]);
    wire        if_h_done       = (if_h_cnt == if_h_lim);
    wire        if_r_done       = (if_r_cnt == r_lim);
    wire        if_w_p1_done    = (if_w_cnt_p1[1]);
    wire        if_h_p1_done    = (if_h_cnt_p1 == if_h_lim);
    wire        if_r_p1_done    = (if_r_cnt_p1 == r_lim);
    wire        if3_feed_done   = (if_w_done & if_h_done & if_r_done & GLB_ifmap_ready);
    wire        if1_feed_done   = (if_h_done & if_r_done & GLB_ifmap_ready);
    // feed ifmap =================================================================================================

    // feed ipsum counter =========================================================================================
    // e -> p -> t
    // L0 : tag y = {2'd0, ipsum_t_cnt}     tag x = ipsum_e_cnt
    // L13: tag y = {4'd0}                  tag x = {ipsum_t_cnt[0], ipsum_t_cnt[0]} + {ipsum_e_cnt}
    // L4:  tag y = {4'd0}                  tag x = ipsum_e_cnt
    //                                  LFIRST  LMID    LLAST
    reg  [2:0]  ipsum_e_cnt;        //  0~5     0~2     0~5
    reg  [1:0]  ipsum_p_cnt;        //  0~3     0~3     0~0
    reg  [1:0]  ipsum_t_cnt;        //  0~3     0~1     0~0
    wire        ip_e_done       = (ipsum_e_cnt     == e_lim);
    wire        ip_p_done       = (ipsum_p_cnt     == p_lim);
    wire        ip_t_done       = (ipsum_t_cnt     == t_lim);
    wire        ip_feed_done    = (ip_e_done & ip_p_done & ip_t_done & GLB_ipsum_ready);
    // feed ipsum counter =========================================================================================

    // get opsum counter ==========================================================================================
    // e -> p -> t                                                      LFIRST  LMID    LLAST
    reg  [2:0]  opsum_e_cnt;  //    0~5     0~2     0~5
    reg  [1:0]  opsum_p_cnt;  //    0~3     0~3     0~0
    reg  [1:0]  opsum_t_cnt;  //    0~3     0~1     0~0
    reg  [7:0]  opsum_F_cnt;  //    0~255   0~255   0~255
    wire        op_e_done       = (opsum_e_cnt == e_lim);
    wire        op_p_done       = (opsum_p_cnt == p_lim);
    wire        op_t_done       = (opsum_t_cnt == t_lim);
    wire        op_F_done       = (opsum_F_cnt == 8'd255);
    wire        op_get_done     = (op_e_done & op_p_done & op_t_done & GLB_opsum_valid);    // e p t

    wire        op_pass_done    = (op_get_done & op_F_done);                                // e p t F
    wire        layer_done      = (op_pass_done & tile_M_done & tile_C_done & tile_E_done);
    // get opsum counter ==========================================================================================

    // FSM transition =============================================================================================
    always @(posedge clk or posedge rst)
        CS <= rst ? LAYERIDLE : NS;
    // FSM transition =============================================================================================

    // Next state logic ===========================================================================================
    always @(*)begin
        case(CS)
            LAYERIDLE:      NS = (layer_enable)         ?   SETLN           :   LAYERIDLE;
            SETLN:          NS = SETXID;
            SETXID:         NS = (xid_cnt==7'd71)       ?   SETYID          :   SETXID;
            SETYID:         NS = (yid_cnt==4'd11)       ?   PASSIDLE        :   SETYID;
            PASSIDLE:       NS = (pass_enable)          ?   FEEDF_ADDR      :   PASSIDLE;

            FEEDF_ADDR:     NS = (GLB_filter_ready)     ?   FEEDFILTER      :   FEEDF_ADDR;
            FEEDFILTER:     NS = ker_feed_done          ?   FEEDIF3_ADDR0   :   FEEDFILTER;

            FEEDIF3_ADDR0:  NS = (GLB_ifmap_ready)      ?   FEEDIF3_ADDR1   :   FEEDIF3_ADDR0;
            FEEDIF3_ADDR1:  NS = (GLB_ifmap_ready)      ?   FEEDIF3         :   FEEDIF3_ADDR1;
            FEEDIF3:        NS = if3_feed_done          ?   FEEDIP_ADDR0    :   FEEDIF3;

            FEEDIF1_ADDR0:  NS = (GLB_ifmap_ready)      ?   FEEDIF1_ADDR1   :   FEEDIF1_ADDR0;
            FEEDIF1_ADDR1:  NS = (GLB_ifmap_ready)      ?   FEEDIF1         :   FEEDIF1_ADDR1;
            FEEDIF1:        NS = if1_feed_done          ?   FEEDIP_ADDR0    :   FEEDIF1;

            FEEDIP_ADDR0:   NS = (GLB_ipsum_ready)      ?   FEEDIP_ADDR1    :   FEEDIP_ADDR0;
            FEEDIP_ADDR1:   NS = (GLB_ipsum_ready)      ?   FEEDIPSUM       :   FEEDIP_ADDR1;
            FEEDIPSUM:      NS = ip_feed_done           ?   GETOPADDR       :   FEEDIPSUM;

            GETOPADDR:      NS = GETOPSUM;
            GETOPSUM:       if(op_get_done) NS = op_pass_done ? PASSDONE : FEEDIF1_ADDR0;
                            else            NS = GETOPSUM;
            PASSDONE:       NS = layer_done             ?   LAYERIDLE       :   PASSIDLE;
            default:        NS = LAYERIDLE;
        endcase
    end
    // Next state logic ===========================================================================================

    // sequantial logic ===========================================================================================
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            layer_info_reg  <=  2'd0;
            xid_cnt         <=  7'd0;   // 0~71
            yid_cnt         <=  4'd0;   // 0~11
            ker_w_cnt       <=  2'd0;   // 0~2
            ker_h_cnt       <=  2'd0;   // 0~2
            ker_r_cnt       <=  2'd0;   // 0~3
            ker_p_cnt       <=  2'd0;   // 0~3
            ker_t_cnt       <=  2'd0;   // 0~3

            if_w_cnt        <=  2'd0;   // 0~2
            if_h_cnt        <=  3'd0;   // 0~7
            if_r_cnt        <=  2'd0;   // 0~3
            if_w_cnt_p1     <=  2'd0;   // 0~2
            if_h_cnt_p1     <=  3'd0;   // 0~7
            if_r_cnt_p1     <=  2'd0;   // 0~3

            ipsum_e_cnt     <=  3'd0;   // 0~5
            ipsum_p_cnt     <=  2'd0;   // 0~3
            ipsum_t_cnt     <=  2'd0;   // 0~3

            opsum_e_cnt     <=  3'd0;   // 0~5
            opsum_p_cnt     <=  2'd0;   // 0~3
            opsum_t_cnt     <=  2'd0;   // 0~3
            opsum_F_cnt     <=  8'd0;   // 0~255

            tile_M_cnt      <=  3'd0;   //      0~3 (64/16)          0~7 (64/8)          0~0 (1/1)
            tile_C_cnt      <=  2'd0;   //      0~0 (1/1)            0~3 (64/16)         0~3 (64/16)
            tile_E_cnt      <=  7'd0;   //      0~41 +1 (256/6)      0~84 +1 (256/3)     0~41 +1 (256/6)
            bram_b_addr     <=  32'd0;
        end else begin
            case(CS)
                LAYERIDLE:begin
                    if(layer_enable)begin
                        layer_info_reg <= layer_info;   // 0 1 2
                    end
                    xid_cnt         <=  7'd0;   // 0~71
                    yid_cnt         <=  4'd0;   // 0~11
                    ker_w_cnt       <=  2'd0;   // 0~2
                    ker_h_cnt       <=  2'd0;   // 0~2
                    ker_r_cnt       <=  2'd0;   // 0~3
                    ker_p_cnt       <=  2'd0;   // 0~3
                    ker_t_cnt       <=  2'd0;   // 0~3
                    if_w_cnt        <=  2'd0;   // 0~2
                    if_h_cnt        <=  3'd0;   // 0~7
                    if_r_cnt        <=  2'd0;   // 0~3
                    ipsum_e_cnt     <=  3'd0;   // 0~5
                    ipsum_p_cnt     <=  2'd0;   // 0~3
                    ipsum_t_cnt     <=  2'd0;   // 0~3
                    opsum_e_cnt     <=  3'd0;   // 0~5
                    opsum_p_cnt     <=  2'd0;   // 0~3
                    opsum_t_cnt     <=  2'd0;   // 0~3
                    opsum_F_cnt     <=  8'd0;   // 0~255
                    tile_M_cnt      <=  3'd0;   // 0~3 (64/16)          0~7 (64/8)          0~0 (1/1)
                    tile_C_cnt      <=  2'd0;   // 0~0 (1/1)            0~3 (64/16)         0~3 (64/16)
                    tile_E_cnt      <=  7'd0;   // 0~41 +1 (256/6)      0~84 +1 (256/3)     0~41 +1 (256/6)
                end
                SETLN:begin
                    // SET_LN       = 1
                    // LN_config_in = (layer_info_reg==L0) ? 11'b11011011011 : 11'b11111111111
                end
                SETXID:begin
                    xid_cnt <= xid_cnt + 7'd1;  // 0~71
                end
                SETYID:begin
                    yid_cnt <= yid_cnt + 4'd1;  // 0~11
                end
                PASSIDLE:begin
                    // PE_en        = 1
                    // PE_config    = {p_lim, q_lim, 8'd255};
                    ker_w_cnt       <=  2'd0;
                    ker_h_cnt       <=  2'd0;
                    ker_r_cnt       <=  2'd0;
                    ker_p_cnt       <=  2'd0;
                    ker_t_cnt       <=  2'd0;

                    if_w_cnt        <=  2'd0;
                    if_h_cnt        <=  3'd0;
                    if_r_cnt        <=  2'd0;
                    if_w_cnt_p1     <=  2'd1;
                    if_h_cnt_p1     <=  3'd0;
                    if_r_cnt_p1     <=  2'd0;

                    ipsum_e_cnt     <=  3'd0;
                    ipsum_p_cnt     <=  2'd0;
                    ipsum_t_cnt     <=  2'd0;

                    opsum_e_cnt     <=  3'd0;
                    opsum_p_cnt     <=  2'd0;
                    opsum_t_cnt     <=  2'd0;
                    opsum_F_cnt     <=  8'd0;

                    bram_b_addr     <=  `GLB_WADDR_OFFSET;
                end
                FEEDF_ADDR:begin
                    if(GLB_filter_ready)
                        bram_b_addr     <=  `GLB_WADDR_OFFSET + 4;
                end
                FEEDFILTER:begin
                    if(GLB_filter_ready)begin // w -> h -> r -> p -> t
                        bram_b_addr <= bram_b_addr + 3'd4;
                        if(ker_w_done)begin
                            ker_w_cnt <= 2'd0;
                            if(ker_h_done)begin
                                ker_h_cnt <= 2'd0;
                                if(ker_r_done)begin
                                    ker_r_cnt <= 2'd0;
                                    if(ker_p_done)begin
                                        ker_p_cnt <= 2'd0;
                                        ker_t_cnt <= ker_t_cnt + 2'd1;
                                    end else begin
                                        ker_p_cnt <= ker_p_cnt + 2'd1;
                                    end
                                end else begin
                                    ker_r_cnt <= ker_r_cnt + 2'd1;
                                end
                            end else begin
                                ker_h_cnt <= ker_h_cnt + 2'd1;
                            end
                        end else begin
                            ker_w_cnt <= ker_w_cnt + 2'd1;
                        end
                    end
                end
                FEEDIF3_ADDR0:begin
                    bram_b_addr     <=  `GLB_IFADDR_OFFSET - 4; // pad 0
                    if_w_cnt        <=  2'd0;
                    if_h_cnt        <=  3'd0;
                    if_r_cnt        <=  2'd0;
                    if_w_cnt_p1     <=  2'd1;
                    if_h_cnt_p1     <=  3'd0;
                    if_r_cnt_p1     <=  2'd0;
                end
                FEEDIF3_ADDR1:begin
                    if(GLB_ifmap_ready)
                        bram_b_addr     <=  `GLB_IFADDR_OFFSET;
                end
                FEEDIF3:begin
                    // for tag (data)
                    if(GLB_ifmap_ready)begin
                        if(if_w_done)begin
                            if_w_cnt <= 2'd0;
                            if(if_h_done)begin
                                if_h_cnt <= 2'd0;
                                if(if_r_done)begin
                                    if_r_cnt <= 2'd0;
                                end else begin
                                    if_r_cnt <= if_r_cnt + 2'd1;
                                end
                            end else begin
                                if_h_cnt <= if_h_cnt + 2'd1;
                            end
                        end else begin
                            if_w_cnt <= if_w_cnt + 2'd1;
                        end
                    end
                    // for bram addr
                    if(GLB_ifmap_ready)begin
                        if(if_w_p1_done)begin
                            if_w_cnt_p1 <= 2'd0;
                            if(if_h_p1_done)begin
                                if_h_cnt_p1 <= 2'd0;
                                if(if_r_p1_done)begin
                                    if_r_cnt_p1 <= 2'd0;
                                end else begin
                                    if_r_cnt_p1 <= if_r_cnt_p1 + 2'd1;
                                end
                            end else begin
                                if_h_cnt_p1 <= if_h_cnt_p1 + 2'd1;
                            end
                        end else begin
                            if_w_cnt_p1 <= if_w_cnt_p1 + 2'd1;
                        end
                    end
                    // bram addr
                    if(GLB_ifmap_ready)begin
                        if(if_w_p1_done)begin   // next row   + 256 - 2
                            bram_b_addr     <=  bram_b_addr + {8'd254, 2'd0};
                        end else begin
                            bram_b_addr     <=  bram_b_addr + {3'b100};
                        end
                    end
                end
                FEEDIP_ADDR0:begin                                      // M_idx * pt * e * 256 + F_idx
                    //bram_b_addr     <= `GLB_OPADDR_OFFSET + {{{{(tile_M_cnt << (m_shift_value)) * (e_lim + 3'd1)}, 8'd0} + opsum_F_cnt}, 2'd0};   // M_idx * p * t * e + F
                    bram_b_addr     <= `GLB_OPADDR_OFFSET + {{{{(tile_M_mul_pt) * (e_lim + 3'd1)}, 8'd0} + opsum_F_cnt}, 2'd0};
                    ipsum_e_cnt     <=  3'd0;
                    ipsum_p_cnt     <=  2'd0;
                    ipsum_t_cnt     <=  2'd0;
                end
                FEEDIP_ADDR1:begin
                    if(GLB_ipsum_ready)
                        bram_b_addr <= bram_b_addr + {9'd256, 2'd0};
                end
                FEEDIPSUM:begin // e -> p -> t
                    // for tag (data)
                    if(GLB_ipsum_ready)begin
                        if(ip_e_done)begin
                            ipsum_e_cnt <= 3'd0;
                            if(ip_p_done)begin
                                ipsum_p_cnt <= 2'd0;
                                if(ip_t_done)begin
                                    ipsum_t_cnt <= 2'd0;
                                end else begin
                                    ipsum_t_cnt <= ipsum_t_cnt + 2'd1;
                                end
                            end else begin
                                ipsum_p_cnt <= ipsum_p_cnt + 2'd1;
                            end
                        end else begin
                            ipsum_e_cnt <= ipsum_e_cnt + 3'd1;
                        end
                    end
                    // bram addr
                    if(GLB_ipsum_ready)begin
                        bram_b_addr <= bram_b_addr + {9'd256, 2'd0};
                    end
                end
                FEEDIF1_ADDR0:begin
                    bram_b_addr     <=  `GLB_IFADDR_OFFSET + {opsum_F_cnt + 8'd1, 2'd0};    // F_cnt 255
                    if_w_cnt        <=  2'd0;
                    if_h_cnt        <=  3'd0;
                    if_r_cnt        <=  2'd0;
                    if_w_cnt_p1     <=  2'd0;
                    if_h_cnt_p1     <=  3'd1;
                    if_r_cnt_p1     <=  2'd0;
                end
                FEEDIF1_ADDR1:begin
                    bram_b_addr     <=  bram_b_addr + {9'd256, 2'd0};    // next row
                end
                FEEDIF1:begin
                    // for tag
                    if(GLB_ifmap_ready)begin
                        if(if_h_done)begin
                            if_h_cnt <= 2'd0;
                            if(if_r_done)begin
                                if_r_cnt <= 2'd0;
                            end else begin
                                if_r_cnt <= if_r_cnt + 2'd1;
                            end
                        end else begin
                            if_h_cnt <= if_h_cnt + 2'd1;
                        end
                    end
                    if(GLB_ifmap_ready)begin
                        bram_b_addr <= bram_b_addr + {9'd256, 2'd0};
                    end
                end
                GETOPADDR:begin // M_idx * p * t * e + F
                    // bram_b_addr     <= `GLB_OPADDR_OFFSET + {{{{(tile_M_cnt << (m_shift_value)) * (e_lim + 3'd1)}, 8'd0} + opsum_F_cnt}, 2'd0};
                    bram_b_addr     <= `GLB_OPADDR_OFFSET + {{{{(tile_M_mul_pt) * (e_lim + 3'd1)}, 8'd0} + opsum_F_cnt}, 2'd0};
                    opsum_e_cnt     <= 3'd0;
                    opsum_p_cnt     <= 2'd0;
                    opsum_t_cnt     <= 2'd0;
                end
                GETOPSUM:begin
                    // for tag (data)
                    if(GLB_opsum_valid)begin
                        if(op_e_done)begin
                            opsum_e_cnt <= 3'd0;
                            if(op_p_done)begin
                                opsum_p_cnt <= 2'd0;
                                if(op_t_done)begin
                                    opsum_t_cnt <= 2'd0;
                                    opsum_F_cnt <= opsum_F_cnt + 8'd1;
                                end else begin
                                    opsum_t_cnt <= opsum_t_cnt + 2'd1;
                                end
                            end else begin
                                opsum_p_cnt <= opsum_p_cnt + 2'd1;
                            end
                        end else begin
                            opsum_e_cnt <= opsum_e_cnt + 3'd1;
                        end
                    end
                    // bram addr
                    if(tile_C_done)begin
                        if(GLB_opsum_valid)begin
                            if(op_e_done)begin
                                if(op_p_done)begin
                                    //bram_b_addr <= bram_b_addr + {{{(e_lim + 3'd1), 2'd0} - e_lim}, 8'd0, 2'd0};    // p done, back to first row add p channels + [((p)*e) - (e-1)] *256
                                    bram_b_addr <= bram_b_addr + {9'd256, 2'd0};
                                end else begin
                                    bram_b_addr <= bram_b_addr - {e_lim, 8'd0, 2'd0};    // e done do p + 1  addr back to first row (-(e-1)*256)
                                end
                            end else begin
                                bram_b_addr <= bram_b_addr + {9'd256, 2'd0};
                            end
                        end
                    end else begin
                        if(GLB_opsum_valid)begin
                            bram_b_addr <= bram_b_addr + {9'd256, 2'd0};
                        end
                    end
                end
                PASSDONE:begin
                    if(tile_M_done)begin
                        tile_M_cnt <= 2'd0;
                        if(tile_C_done)begin
                            tile_C_cnt <= 2'd0;
                            tile_E_cnt <= (tile_E_done) ? 7'd0 : tile_E_cnt + 7'd1;
                        end else begin
                            tile_C_cnt <= tile_C_cnt + 2'd1;
                        end
                    end else begin
                        tile_M_cnt <= tile_M_cnt + 3'd1;
                    end
                end
            endcase
        end
    end
    // sequantial logic ===========================================================================================

    // ID LIST logic ==============================================================================================
    // IFMAP ID
    always@(*)begin
        for(i=0;i<12;i=i+1)begin
            case(layer_info_reg)
                L0:         IF_YID[i] = 4'd0;
                L13:        IF_YID[i] = i/3;
                L4:         IF_YID[i] = i/3;
                default:    IF_YID[i] = 4'd0;
            endcase
            for(j=0;j<6;j=j+1)begin
                case(layer_info_reg)
                    L0:         IF_XID[i*6+j] = (i%3) + j;
                    L13:        IF_XID[i*6+j] = (i%3) + (j%3);
                    L4:         IF_XID[i*6+j] = (i%3) + j;
                    default:    IF_XID[i*6+j] = 3'd0;
                endcase
            end
        end
    end
    // WEIGHT ID
    always@(*)begin
        for(i=0;i<12;i=i+1)begin
                W_YID[i] = i;
            for(j=0;j<6;j=j+1)begin
                case(layer_info_reg)
                    L0:         W_XID[i*6+j] = 3'd0;
                    L13:        W_XID[i*6+j] = j/3;
                    L4:         W_XID[i*6+j] = 3'd0;
                    default:    W_XID[i*6+j] = 3'd0;
                endcase
            end
        end
    end
    // IPSUM ID
    always@(*)begin
        for(i=0;i<12;i=i+1)begin
            case(layer_info_reg)
                L0:         IP_YID[i] = (i%3==0)    ? (i/3) :   `DEFAULT_YID;   // 0 X X 0 X X 0 X X 0 X X
                L13:        IP_YID[i] = (i==0)      ? 4'd0  :   `DEFAULT_YID;   // 0 X X X X X X X X X X X
                L4:         IP_YID[i] = (i==0)      ? 4'd0  :   `DEFAULT_YID;   // 0 X X X X X X X X X X X
                default:    IP_YID[i] = 4'd0;
            endcase
            for(j=0;j<6;j=j+1)begin
                IP_XID[i*6+j] = j;                                              // 0 1 2 3 4 5
            end
        end
    end
    // OPSUM ID
    always@(*)begin
        for(i=0;i<12;i=i+1)begin
            case(layer_info_reg)
                L0:         OP_YID[i] = (i%3==2)    ? (i/3) :   `DEFAULT_YID;   // X X 0 X X 1 X X 2 X X 3
                L13:        OP_YID[i] = (i==11)     ? 4'd0  :   `DEFAULT_YID;   // X X X X X X X X X X X 0
                L4:         OP_YID[i] = (i==11)     ? 4'd0  :   `DEFAULT_YID;   // X X X X X X X X X X X 0
                default:    OP_YID[i] = 4'd0;
            endcase
            for(j=0;j<6;j=j+1)begin
                OP_XID[i*6+j] = j;                                              // 0 1 2 3 4 5
            end
        end
    end
    // ID LIST logic ==============================================================================================

    // parameter ==================================================================================================
    always @(*) begin
        case(layer_info_reg)
            L0:begin
                e_lim           = (tile_E_done) ? 3'd3 : 3'd5;    // 4 : 6
                p_lim           = 2'd3;
                q_lim           = 2'd0;
                r_lim           = 2'd0;
                t_lim           = 2'd3;
                M_lim           = 3'd3;
                C_lim           = 2'd0;
                E_lim           = 7'd42;
                m_shift_value   = 3'd4;
            end
            L13:begin
                e_lim           = (tile_E_done) ? 3'd0 : 3'd2;    // 1 : 3
                p_lim           = 2'd3;
                q_lim           = 2'd3;
                r_lim           = 2'd3;
                t_lim           = 2'd1;
                M_lim           = 3'd7;
                C_lim           = 2'd3;
                E_lim           = 7'd85;
                m_shift_value   = 3'd3;
            end
            default:begin
                e_lim           = (tile_E_done) ? 3'd3 : 3'd5;    // 4 : 6
                p_lim           = 2'd0;
                q_lim           = 2'd3;
                r_lim           = 2'd3;
                t_lim           = 2'd0;
                M_lim           = 3'd0;
                C_lim           = 2'd3;
                E_lim           = 7'd42;
                m_shift_value   = 3'd0;
            end
        endcase
    end
    // parameter ==================================================================================================

    // PE ARRAY signals ===========================================================================================
    // Controll
    assign SET_LN               = (CS==SETLN);
    assign SET_XID              = (CS==SETXID);
    assign SET_YID              = (CS==SETYID);
    assign LN_config_in         = (layer_info_reg==L0) ? 11'b11011011011 : 11'b11111111111;
    assign PE_en                = {`NUMS_PE_ROW*`NUMS_PE_COL{(CS==PASSIDLE) ? 1'b1 : 1'b0}};
    assign PE_config            = {p_lim, q_lim, 8'd255};   // p q F
    // ID
    assign ifmap_XID_scan_in    = IF_XID[xid_cnt];
    assign filter_XID_scan_in   =  W_XID[xid_cnt];
    assign ipsum_XID_scan_in    = IP_XID[xid_cnt];
    assign opsum_XID_scan_in    = OP_XID[xid_cnt];
    assign ifmap_YID_scan_in    = IF_YID[yid_cnt];
    assign filter_YID_scan_in   =  W_YID[yid_cnt];
    assign ipsum_YID_scan_in    = IP_YID[yid_cnt];
    assign opsum_YID_scan_in    = OP_YID[yid_cnt];
    // TAG
    assign ifmap_tag_X          = if_h_cnt;
    assign ifmap_tag_Y          = {2'b00, if_r_cnt};
    assign filter_tag_X         = {2'd0, (layer_info_reg==L13 ? ker_t_cnt[0] : 1'b0)};

    // assign filter_tag_Y         = {(layer_info_reg==L0  ? ker_t_cnt : ker_r_cnt), ker_h_cnt};     // t*3 + h
    assign filter_tag_Y         = (layer_info_reg==L0  ? {ker_t_cnt + {1'b0, ker_t_cnt, 1'b0}} : {ker_r_cnt + {1'b0, ker_r_cnt, 1'b0}}) + {2'b00, ker_h_cnt};     // t*3+h  or  r*3+h 4 bits

    assign ipsum_tag_X          = (layer_info_reg==L13) ? ({ipsum_t_cnt[0], ipsum_t_cnt[0]} + {ipsum_e_cnt}) : ipsum_e_cnt;
    assign ipsum_tag_Y          = {2'd0, (layer_info_reg==L0 ? ipsum_t_cnt : 2'd0)};
    assign opsum_tag_X          = (layer_info_reg==L13) ? ({opsum_t_cnt[0], opsum_t_cnt[0]} + {opsum_e_cnt}) : opsum_e_cnt;
    assign opsum_tag_Y          = {2'd0, (layer_info_reg==L0 ? opsum_t_cnt : 2'd0)};
    // Handshake
    assign GLB_ifmap_valid      = (CS==FEEDIF1 || CS==FEEDIF3);
    assign GLB_filter_valid     = (CS==FEEDFILTER);
    assign GLB_ipsum_valid      = (CS==FEEDIPSUM);
    assign GLB_opsum_ready      = (CS==GETOPSUM);
    always@(*)begin
        if(CS==FEEDIF3 && if_w_cnt==2'd0)               GLB_data_in          = 32'h80808080;     // fisrt column
        else if(CS==FEEDIF1 && opsum_F_cnt==8'd255)     GLB_data_in          = 32'h80808080;     //  last column
        else if(CS==FEEDIPSUM && tile_C_cnt==2'd0)      GLB_data_in          = `DATA_SIZE'd0;   //  bias = 0
        else                                            GLB_data_in          = (bram_b_dout);
    end
    // PE ARRAY signals ======================================================================================================

    // BRAM ==================================================================================================================
    assign bram_b_en            = 1'b1;
    always @(*) begin
        if(CS==GETOPSUM && GLB_opsum_valid)begin
            if(tile_C_done)begin
                bram_b_din = (PPU_data_out << {opsum_p_cnt, 3'd0});
                bram_b_web =  4'b0001 << opsum_p_cnt;
            end else begin
                bram_b_din = GLB_data_out;
                bram_b_web = 4'b1111;
            end
        end else begin
            bram_b_din = GLB_data_out;
            bram_b_web = 4'b0000;
        end
    end
    // BRAM ==================================================================================================================

    // TOP signals ===========================================================================================================
    assign pass_done            = (CS==PASSDONE);
    assign pass_ready           = (CS==PASSIDLE);
    // TOP signals ===========================================================================================================

    // PE array instance ==========================================================================================
    PE_array #(
        .NUMS_PE_ROW        (`NUMS_PE_ROW       ),
        .NUMS_PE_COL        (`NUMS_PE_COL       ),
        .XID_BITS           (`XID_BITS          ),
        .YID_BITS           (`YID_BITS          ),
        .DATA_SIZE          (`DATA_BITS         ),
        .CONFIG_SIZE        (`CONFIG_SIZE       )
    ) PE_array_u (
        .clk                (clk                ),
        .rst                (rst                ),
        .SET_XID            (SET_XID            ),
        .SET_YID            (SET_YID            ),
        .ifmap_XID_scan_in  (ifmap_XID_scan_in  ),
        .filter_XID_scan_in (filter_XID_scan_in ),
        .ipsum_XID_scan_in  (ipsum_XID_scan_in  ),
        .opsum_XID_scan_in  (opsum_XID_scan_in  ),
        .ifmap_YID_scan_in  (ifmap_YID_scan_in  ),
        .filter_YID_scan_in (filter_YID_scan_in ),
        .ipsum_YID_scan_in  (ipsum_YID_scan_in  ),
        .opsum_YID_scan_in  (opsum_YID_scan_in  ),
        .SET_LN             (SET_LN             ),
        .LN_config_in       (LN_config_in       ),
        .PE_en              (PE_en              ),
        .PE_config          (PE_config          ),
        .ifmap_tag_X        (ifmap_tag_X        ),
        .ifmap_tag_Y        (ifmap_tag_Y        ),
        .filter_tag_X       (filter_tag_X       ),
        .filter_tag_Y       (filter_tag_Y       ),
        .ipsum_tag_X        (ipsum_tag_X        ),
        .ipsum_tag_Y        (ipsum_tag_Y        ),
        .opsum_tag_X        (opsum_tag_X        ),
        .opsum_tag_Y        (opsum_tag_Y        ),
        .GLB_ifmap_valid    (GLB_ifmap_valid    ),
        .GLB_ifmap_ready    (GLB_ifmap_ready    ),
        .GLB_filter_valid   (GLB_filter_valid   ),
        .GLB_filter_ready   (GLB_filter_ready   ),
        .GLB_ipsum_valid    (GLB_ipsum_valid    ),
        .GLB_ipsum_ready    (GLB_ipsum_ready    ),
        .GLB_data_in        (GLB_data_in        ),
        .GLB_opsum_valid    (GLB_opsum_valid    ),
        .GLB_opsum_ready    (GLB_opsum_ready    ),
        .GLB_data_out       (GLB_data_out       ),
        .op_get_done        (op_get_done        ),
        .op_pass_done       (op_pass_done       ),
        .PE_reset           (pass_done          ),

        .opsum_e_cnt        (opsum_e_cnt        ),
        .opsum_t_cnt        (opsum_t_cnt        ),
        .layer_info         (layer_info_reg     )
    );
    // PE array instance ==========================================================================================

    // PPU instance ===============================================================================================
    PPU PPU_u (
        .data_in            (GLB_data_out       ),
        .scaling_factor     (PPU_scaling_factor ),
        .relu_en            (PPU_relu_en        ),
        .data_out           (PPU_data_out       )
    );
    // PPU instance ===============================================================================================

endmodule
