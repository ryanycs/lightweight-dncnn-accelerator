`timescale 1ns/10ps
`include "define.svh"
`include "Controller.v"
`include "PE.v"
`include "PE_array.v"
`include "PPU.v"

`define CYCLE           20.0
// `define END_CYCLE       ((3*500+20)*(10**6))    // L0 + L1 *3 + L4
`define END_CYCLE       (2*(10**9))

`define BRAM_SIZE       (2**17)
`define IMAGE_SIZE      (256*256)

`define PAD_IMAGE_SIZE  (258*256)
`define KERNEL_SIZE     ( 9)

`define SHAPE_C_MAX     (64)
`define SHAPE_M_MAX     (64)

// L0 PARAMETER
`define L0_SHAPE_C      ( 1)
`define L0_SHAPE_M      (64)
`define L0_MAP_M        (64)
`define L0_MAP_P        ( 4)
`define L0_MAP_T        ( 4)
`define L0_MAP_PT       (16)
`define L0_MAP_E        ( 6)
`define L0_MAP_Q        ( 1)
`define L0_MAP_R        ( 1)
`define L0_MAP_QR       ( 1)
`define L0_E_IDX_LAST   (42)

// L1 L2 L3 PARAMETER
`define L13_SHAPE_C     (64)
`define L13_SHAPE_M     (64)
`define L13_MAP_M       (64)
`define L13_MAP_P       ( 4)
`define L13_MAP_T       ( 2)
`define L13_MAP_PT      ( 8)
`define L13_MAP_E       ( 3)
`define L13_MAP_Q       ( 4)
`define L13_MAP_R       ( 4)
`define L13_MAP_QR      (16)
`define L13_E_IDX_LAST  (85)

// L4 PARAMETER
`define L4_SHAPE_C      (64)
`define L4_SHAPE_M      ( 1)
`define L4_MAP_M        ( 1)
`define L4_MAP_P        ( 1)
`define L4_MAP_T        ( 1)
`define L4_MAP_PT       ( 1)
`define L4_MAP_E        ( 6)
`define L4_MAP_Q        ( 4)
`define L4_MAP_R        ( 4)
`define L4_MAP_QR       (16)
`define L4_E_IDX_LAST   (42)

// PATTERN
`define L0_IFMAP_DAT        "./dat/layer0_dat/layer0_input_image_pad.hex"
`define L1_IFMAP_DAT        "./dat/layer1_dat/layer1_input_pad.hex"
`define L2_IFMAP_DAT        "./dat/layer2_dat/layer2_input_pad.hex"
`define L3_IFMAP_DAT        "./dat/layer3_dat/layer3_input_pad.hex"
`define L4_IFMAP_DAT        "./dat/layer4_dat/layer4_input_pad.hex"

`define L0_OFMAP_DAT        "./dat/layer0_dat/layer0_opsum_golden.hex"
`define L1_OFMAP_DAT        "./dat/layer1_dat/layer1_golden.hex"
`define L2_OFMAP_DAT        "./dat/layer2_dat/layer2_golden.hex"
`define L3_OFMAP_DAT        "./dat/layer3_dat/layer3_golden.hex"
`define L4_OFMAP_DAT        "./dat/layer4_dat/layer4_golden.hex"

`define L0_WEIGHT_DAT       "./dat/layer0_dat/layer0_weight.hex"
`define L1_WEIGHT_DAT       "./dat/layer1_dat/layer1_weight.hex"
`define L2_WEIGHT_DAT       "./dat/layer2_dat/layer2_weight.hex"
`define L3_WEIGHT_DAT       "./dat/layer3_dat/layer3_weight.hex"
`define L4_WEIGHT_DAT       "./dat/layer4_dat/layer4_weight.hex"

`define L1_BIAS_DAT         "./dat/layer1_dat/layer1_bias.hex"
`define L2_BIAS_DAT         "./dat/layer2_dat/layer2_bias.hex"
`define L3_BIAS_DAT         "./dat/layer3_dat/layer3_bias.hex"

`define L0_OFMAP_OUT_DAT    "./out_dat/layer0_ofmap_out.hex"
`define L1_OFMAP_OUT_DAT    "./out_dat/layer1_ofmap_out.hex"
`define L2_OFMAP_OUT_DAT    "./out_dat/layer2_ofmap_out.hex"
`define L3_OFMAP_OUT_DAT    "./out_dat/layer3_ofmap_out.hex"
`define L4_OFMAP_OUT_DAT    "./out_dat/layer4_ofmap_out.hex"

module testfixture;

    logic [31:0] BRAM_DATA      [0 : `BRAM_SIZE-1];
    logic [31:0] IFMAP_DDR      [0 : `PAD_IMAGE_SIZE * (`SHAPE_C_MAX/4) - 1];
    logic [31:0] OFMAP_DDR      [0 : `PAD_IMAGE_SIZE * (`SHAPE_C_MAX/4) - 1];

    logic [31:0] L0_WEIGHT_DDR   [0 : `L0_SHAPE_M  * ( `L0_SHAPE_C/ `L0_MAP_Q) * `KERNEL_SIZE - 1];
    logic [31:0] L1_WEIGHT_DDR   [0 : `L13_SHAPE_M * (`L13_SHAPE_C/`L13_MAP_Q) * `KERNEL_SIZE - 1];
    logic [31:0] L2_WEIGHT_DDR   [0 : `L13_SHAPE_M * (`L13_SHAPE_C/`L13_MAP_Q) * `KERNEL_SIZE - 1];
    logic [31:0] L3_WEIGHT_DDR   [0 : `L13_SHAPE_M * (`L13_SHAPE_C/`L13_MAP_Q) * `KERNEL_SIZE - 1];
    logic [31:0] L4_WEIGHT_DDR   [0 : `L4_SHAPE_M  * ( `L4_SHAPE_C/ `L4_MAP_Q) * `KERNEL_SIZE - 1];

    logic [31:0] L1_BIAS_DDR    [0 : `L13_SHAPE_M - 1];
    logic [31:0] L2_BIAS_DDR    [0 : `L13_SHAPE_M - 1];
    logic [31:0] L3_BIAS_DDR    [0 : `L13_SHAPE_M - 1];

    logic [31:0] OFMAP_GOLDEN   [0 : `IMAGE_SIZE * (`SHAPE_M_MAX/4) - 1];

    logic           rst             = 1;
    logic           clk             = 0;
    logic [2:0]     layer_info;
    logic           layer_enable;
    logic           pass_enable     = 1'b0;
    logic           pass_ready;
    logic           pass_done;

    logic [31:0]    bram_b_addr;
    logic [31:0]    bram_b_din;
    logic [3:0]     bram_b_web;
    logic [31:0]    bram_b_dout;
    logic           bram_b_en;

    logic [31:0]    bram_a_addr     = 32'd0;
    logic [31:0]    bram_a_din      = 32'd0;
    logic [3:0]     bram_a_web      = 4'b0000;
    logic [31:0]    bram_a_dout;
    logic           bram_a_en       = 1'b1;

    logic [31:0]    expect_data;
    logic [31:0]    real_data;
    logic [63:0]    cycle_count;
    int             err, error_flag;

    int             ifmap_ddr_addr;
    int             weight_ddr_addr;
    int             bias_ddr_addr;

    int             ifmap_bram_addr;
    int             ofmap_bram_addr;
    int             weight_bram_addr;
    int             bias_bram_addr;

    int             OPSUM_ROW_THIS_PASS;

    int             fd;

    // Controller instance ==============================================================
    Controller u_Controller (
        .clk(clk),
        .rst(rst),
        .layer_info(layer_info),
        .layer_enable(layer_enable),
        .pass_enable(pass_enable),
        .pass_ready(pass_ready),
        .pass_done(pass_done),
        .bram_b_addr(bram_b_addr),
        .bram_b_din(bram_b_din),
        .bram_b_dout(bram_b_dout),
        .bram_b_en(bram_b_en),
        .bram_b_web(bram_b_web)
    );
    // Controller instance ==============================================================

    // BRAM =============================================================================
    always @(posedge clk or posedge rst) begin
        if(rst)begin
            bram_a_dout <= 32'd0;
            bram_b_dout <= 32'd0;
            // for(int i=0;i<`BRAM_SIZE;i++)
            //     BRAM_DATA[i] <= 32'd0;
        end begin
            // read a ===================================================================
            if ((~|bram_b_web) & (bram_b_en))
                bram_b_dout <= BRAM_DATA[bram_b_addr>>2];
            // read a ===================================================================
            // read b ===================================================================
            if (~|bram_a_web)
                bram_a_dout <= BRAM_DATA[bram_a_addr   ];
            // read b ===================================================================
            // write ====================================================================
            for (int i = 0; i < 4; i++)begin
                if (bram_a_web[i])
                    BRAM_DATA[bram_a_addr   ][(i*8)+:8] <= bram_a_din[(i*8)+:8];
                else if (bram_b_web[i] & (bram_b_en))
                    BRAM_DATA[bram_b_addr>>2][(i*8)+:8] <= bram_b_din[(i*8)+:8];
            end
            // write ====================================================================
        end
    end
    // BRAM =============================================================================

    // CLOCK ============================================================================
    always #(`CYCLE/2) clk = ~clk;
    // CLOCK ============================================================================

    `ifdef FSDB
        initial begin
            $fsdbDumpfile("Controller.fsdb");
            $fsdbDumpvars;
            $fsdbDumpMDA;
        end
    `endif

    // cycle count
    always @(posedge clk or posedge rst)begin
        cycle_count <= rst ? 64'd0 : cycle_count + 64'd1;
    end

    task automatic write_ofmap_back_to_ddr(input int M_IDX, input int E_IDX, input int OPSUM_ROW, input int MAP_T, input int MAP_P, input int MAP_PT, input int MAP_E);
        @(negedge clk);
        for (int TT = 0; TT < MAP_T; TT++) begin
            for (int EE = 0; EE < OPSUM_ROW; EE++) begin
                for (int FF = 0; FF < 256; FF++) begin
                    int ofmap_ddr_addr          =                           ((M_IDX * MAP_T  + TT) *     `PAD_IMAGE_SIZE) + ((E_IDX * MAP_E + EE) * 256) + (FF) + (256);    // padding 1 row
                    ofmap_bram_addr             = (`GLB_OPADDR_OFFSET/4) +  ((M_IDX * MAP_PT + TT) *     OPSUM_ROW * 256) + ((                EE) * 256) + (FF);
                    OFMAP_DDR[ofmap_ddr_addr]   <= BRAM_DATA[ofmap_bram_addr];
                    @(negedge clk);
                end
            end
        end
    endtask

    task automatic check_ddr_ofmap(input int layer_count, output int layer_ofmap_error);
        int LAYER_SHAPE_M, LAYER_MAP_P;
        string LAYER_OFMAP_GOLDEN;
        case(layer_count)
            4:          LAYER_SHAPE_M =  1;
            default:    LAYER_SHAPE_M = 64;
        endcase
        case(layer_count)
            0:          LAYER_OFMAP_GOLDEN = `L0_OFMAP_DAT;
            1:          LAYER_OFMAP_GOLDEN = `L1_OFMAP_DAT;
            2:          LAYER_OFMAP_GOLDEN = `L2_OFMAP_DAT;
            3:          LAYER_OFMAP_GOLDEN = `L3_OFMAP_DAT;
            4:          LAYER_OFMAP_GOLDEN = `L4_OFMAP_DAT;
        endcase
        case(layer_count)
            4:          LAYER_MAP_P = 1;
            default:    LAYER_MAP_P = 4;
        endcase
        $display(" ================================================================================");
        $display(" [ INFO] READ %s GOLDEN", LAYER_OFMAP_GOLDEN);
        $readmemh(LAYER_OFMAP_GOLDEN,       OFMAP_GOLDEN);
        $display(" ================================================================================");
        layer_ofmap_error   = 0;
        for(int M_IDX=0; M_IDX < (LAYER_SHAPE_M/LAYER_MAP_P); M_IDX++)begin
            for(int E_IDX=0; E_IDX < 256; E_IDX++)begin
                for(int F_IDX=0; F_IDX < 256; F_IDX++)begin
                    int ofmap_ddr_addr      = (M_IDX*`PAD_IMAGE_SIZE) + (E_IDX * 256) + F_IDX + 256;    // with pad
                    int ofmap_golden_addr   = (M_IDX*    `IMAGE_SIZE) + (E_IDX * 256) + F_IDX;          // without pad
                    real_data               = OFMAP_DDR[ofmap_ddr_addr];
                    expect_data             = OFMAP_GOLDEN[ofmap_golden_addr];
                    error_flag              = 0;
                    for (int P_IDX = 0; P_IDX < LAYER_MAP_P; P_IDX++)begin
                        if (!((expect_data[P_IDX*8+:8] === real_data[P_IDX*8+:8]) || (expect_data[P_IDX*8+:8] === real_data[P_IDX*8+:8]-1)))begin
                            layer_ofmap_error++;
                            error_flag = 1;
                        end
                    end
                    if (error_flag && layer_ofmap_error<=256) begin
                        $display(" [ERROR] OFMAP[%2d~%2d][%2d][%2d] mismatch exp=%8h get=%8h", M_IDX*LAYER_MAP_P+LAYER_MAP_P-1, M_IDX*LAYER_MAP_P, E_IDX, F_IDX, expect_data, real_data);
                    end
                end
            end
        end
        $display(" [ INFO] PRINT OFMAP FIRST CHANNEL FIRST ROW 8 DATA START");
        $display("         %8h, %8h, %8h, %8h, %8h, %8h, %8h, %8h", OFMAP_DDR[256], OFMAP_DDR[257], OFMAP_DDR[258], OFMAP_DDR[259], OFMAP_DDR[260], OFMAP_DDR[261], OFMAP_DDR[262], OFMAP_DDR[263]);
        $display(" [ INFO] PRINT OFMAP FIRST CHANNEL FIRST ROW 8 DATA  DONE");
    endtask

    task automatic write_ddr_ofmap_to_file(input int layer_count);
        int LAYER_SHAPE_M, LAYER_MAP_P;
        string LAYER_OFMAP_OUTDAT;
        case(layer_count)
            0:          LAYER_SHAPE_M       = 64;
            1:          LAYER_SHAPE_M       = 64;
            2:          LAYER_SHAPE_M       = 64;
            3:          LAYER_SHAPE_M       = 64;
            4:          LAYER_SHAPE_M       =  1;
        endcase
        case(layer_count)
            0:          LAYER_OFMAP_OUTDAT  = `L0_OFMAP_OUT_DAT;
            1:          LAYER_OFMAP_OUTDAT  = `L1_OFMAP_OUT_DAT;
            2:          LAYER_OFMAP_OUTDAT  = `L2_OFMAP_OUT_DAT;
            3:          LAYER_OFMAP_OUTDAT  = `L3_OFMAP_OUT_DAT;
            4:          LAYER_OFMAP_OUTDAT  = `L4_OFMAP_OUT_DAT;
        endcase
        case(layer_count)
            4:          LAYER_MAP_P = 1;
            default:    LAYER_MAP_P = 4;
        endcase
        fd = $fopen(LAYER_OFMAP_OUTDAT, "w");
        $display(" ================================================================================");
        $display(" [ INFO] WRITE FILE %s START", LAYER_OFMAP_OUTDAT);
        for(int M_IDX=0; M_IDX < (LAYER_SHAPE_M/LAYER_MAP_P); M_IDX++)begin
            for(int E_IDX=0; E_IDX < 256; E_IDX++)begin
                for(int F_IDX=0; F_IDX < 256; F_IDX++)begin
                    int ofmap_ddr_addr      = (M_IDX*`PAD_IMAGE_SIZE) + (E_IDX * 256) + F_IDX + 256;
                    real_data               = OFMAP_DDR[ofmap_ddr_addr];
                    $fwrite(fd, "%2H_%2H_%2H_%2H \t // ", real_data[31:24], real_data[23:16], real_data[15: 8], real_data[ 7: 0]);
                    $fwrite(fd, "(%3d, %3d, %3d, %3d)",   real_data[31:24], real_data[23:16], real_data[15: 8], real_data[ 7: 0]);
                    $fwrite(fd, "\tofmap[%2d~%2d][%3d][%3d]\n", M_IDX * LAYER_MAP_P + LAYER_MAP_P-1, M_IDX * LAYER_MAP_P, E_IDX, F_IDX);
                end
            end
        end
        $fclose(fd);
        $display(" [ INFO] WRITE FILE %s  DONE", LAYER_OFMAP_OUTDAT);
        $display(" ================================================================================");
    endtask

    task automatic put_bram_ifmap(input int E_IDX, input int C_IDX, input int OPSUM_ROW, input int MAP_E, input int MAP_R);    // 0~42     0~3
        @(negedge clk);
        bram_a_web      = 4'b1111;
        for(int rr=0; rr<MAP_R; rr++) begin
            for(int hh = 0; hh < (OPSUM_ROW+2); hh++) begin
                for(int ww = 0; ww < 256; ww++) begin
                    ifmap_ddr_addr  =                          (((C_IDX * MAP_R + rr) * 258           * 256 ) + (((E_IDX * MAP_E) + hh) * 256) + ww);
                    ifmap_bram_addr = (`GLB_IFADDR_OFFSET/4) + ((                 rr  * (OPSUM_ROW+2) * 256 ) + (                   hh  * 256) + ww);
                    bram_a_din      = IFMAP_DDR[ifmap_ddr_addr];
                    bram_a_addr     = ifmap_bram_addr;
                    @(negedge clk);
                end
            end
        end
        bram_a_web      = 4'b0000;
    endtask

    task automatic put_bram_weight(input int M_IDX, input int C_IDX, input int MAP_PT, input int MAP_Q, input int MAP_R, input int SHAPE_C, input int LAYER_COUNT);
        @(negedge clk);
        bram_a_web      = 4'b1111;
        for(int PT=0; PT < MAP_PT; PT++) begin
            for(int rr=0; rr < MAP_R; rr++) begin
                for(int RS=0; RS<`KERNEL_SIZE; RS++) begin
                    weight_ddr_addr     =                         (((M_IDX * MAP_PT + PT) * (SHAPE_C/MAP_Q) * 9) + ((C_IDX * MAP_R + rr) * 9) + RS);
                    weight_bram_addr    = (`GLB_WADDR_OFFSET/4) + (((                 PT) *          MAP_R  * 9) + ((                rr) * 9) + RS);
                    bram_a_addr         = weight_bram_addr;
                    case(LAYER_COUNT)
                        0:  bram_a_din          = L0_WEIGHT_DDR[weight_ddr_addr];
                        1:  bram_a_din          = L1_WEIGHT_DDR[weight_ddr_addr];
                        2:  bram_a_din          = L2_WEIGHT_DDR[weight_ddr_addr];
                        3:  bram_a_din          = L3_WEIGHT_DDR[weight_ddr_addr];
                        4:  bram_a_din          = L4_WEIGHT_DDR[weight_ddr_addr];
                    endcase
                    @(negedge clk);
                end
            end
        end
        bram_a_web      = 4'b0000;
    endtask

    task automatic put_bram_bias(input int M_IDX, input int MAP_PT, input int LAYER_COUNT);
        @(negedge clk);
        bram_a_web      = 4'b1111;
        for(int PT=0; PT < MAP_PT; PT++) begin
            bias_ddr_addr       =                         (M_IDX * MAP_PT + PT);
            bias_bram_addr      = (`GLB_BIAS_OFFSET/4) +                   (PT);
            bram_a_addr         = bias_bram_addr;
            case(LAYER_COUNT)
                1:  bram_a_din          = L1_BIAS_DDR[bias_ddr_addr];
                2:  bram_a_din          = L2_BIAS_DDR[bias_ddr_addr];
                3:  bram_a_din          = L3_BIAS_DDR[bias_ddr_addr];
            endcase
            @(negedge clk);
        end
        bram_a_web      = 4'b0000;
    endtask

    task automatic test_L0();
        $display(" ================================================================================");
        $display(" [ INFO] L0 Simulation Start !!! ");
        $display(" ================================================================================");
        layer_info      = 3'd0;
        layer_enable    = 1'b1;
        #(`CYCLE*1);    #1;
        layer_enable    = 1'b0;
        // initial L0 IFMAP WEIGHT DDR DATA
        $display(" ================================================================================");
        $display(" [ INFO] READ %s INTO DDR", `L0_IFMAP_DAT);
        $readmemh(`L0_IFMAP_DAT,    IFMAP_DDR);
        $display(" [ INFO] READ %s INTO DDR", `L0_WEIGHT_DAT);
        $readmemh(`L0_WEIGHT_DAT,   L0_WEIGHT_DDR);
        $display(" ================================================================================");
        // L0 pass for-loop
        for(int FOR_E_IDX=0; FOR_E_IDX <= `L0_E_IDX_LAST; FOR_E_IDX++) begin
            OPSUM_ROW_THIS_PASS = (FOR_E_IDX==`L0_E_IDX_LAST) ? 4 : 6;
            for(int C_IDX=0; C_IDX < `L0_SHAPE_C; C_IDX++) begin
                put_bram_ifmap(FOR_E_IDX, C_IDX, OPSUM_ROW_THIS_PASS, `L0_MAP_E, `L0_MAP_R);
                for(int M_IDX=0; M_IDX<(`L0_SHAPE_M/`L0_MAP_PT); M_IDX++) begin
                    $display(" ================================================================================");
                    $display(" [ INFO] PASS M_IDX=%2d C_IDX=%2d E_IDX=%2d START", M_IDX, C_IDX, FOR_E_IDX);
                    put_bram_weight(M_IDX, C_IDX, `L0_MAP_PT, `L0_MAP_Q, `L0_MAP_R, `L0_SHAPE_C, layer_info);
                    //wait(pass_ready); #1;
                    pass_enable = 1'b1;
                    #(`CYCLE); #1;
                    pass_enable = 1'b0;
                    wait(pass_done); #1;
                    if(C_IDX==`L0_SHAPE_C-1)begin
                        write_ofmap_back_to_ddr( M_IDX, FOR_E_IDX, OPSUM_ROW_THIS_PASS, `L0_MAP_T, `L0_MAP_P, `L0_MAP_PT, `L0_MAP_E);
                    end
                    $display(" [ INFO] PASS M_IDX=%2d C_IDX=%2d E_IDX=%2d  DONE", M_IDX, C_IDX, FOR_E_IDX);
                end
            end
        end
        write_ddr_ofmap_to_file(layer_info);
        check_ddr_ofmap(layer_info, err);
        if(err)begin
            $display(" [ERROR] L0 OFMAP FAIL !! There are %d error in test patterns.", err);
        end else begin
            $display(" [ INFO] L0 OFMAP PASS !! All ofmap data have been generated successfully!");
        end
        $display(" ================================================================================");
        $display(" [ INFO] L0 Simulation DONE !!!");
        $display(" ================================================================================");
    endtask

    task automatic test_L1();
        $display(" ================================================================================");
        $display(" [ INFO] L1 Simulation Start !!! ");
        $display(" ================================================================================");
        layer_info      = 3'd1;
        layer_enable    = 1'b1;
        #(`CYCLE*1);    #1;
        layer_enable    = 1'b0;
        // initial L1 DDR DATA
        $display(" ================================================================================");
        $display(" [ INFO] READ %s INTO DDR", `L1_IFMAP_DAT);
        $readmemh(`L1_IFMAP_DAT,    IFMAP_DDR);
        $display(" [ INFO] READ %s INTO DDR", `L1_WEIGHT_DAT);
        $readmemh(`L1_WEIGHT_DAT,   L1_WEIGHT_DDR);
        $display(" [ INFO] READ %s INTO DDR", `L1_BIAS_DAT);
        $readmemh(`L1_BIAS_DAT,   L1_BIAS_DDR);
        $display(" ================================================================================");
        // L1 pass for-loop
        for(int FOR_E_IDX=0; FOR_E_IDX <= `L13_E_IDX_LAST; FOR_E_IDX++) begin       // 0~85
            OPSUM_ROW_THIS_PASS = (FOR_E_IDX==`L13_E_IDX_LAST) ? 1 : 3;
            for(int C_IDX=0; C_IDX < (`L13_SHAPE_C/`L13_MAP_QR); C_IDX++) begin     // 0~3
                put_bram_ifmap(FOR_E_IDX, C_IDX, OPSUM_ROW_THIS_PASS, `L13_MAP_E, `L13_MAP_R);
                for(int M_IDX=0; M_IDX<(`L13_SHAPE_M/`L13_MAP_PT); M_IDX++) begin   // 0~7
                    if(C_IDX==0)begin
                        put_bram_bias(M_IDX, `L13_MAP_PT, layer_info);
                    end
                    $display(" ================================================================================");
                    $display(" [ INFO] PASS M_IDX=%2d C_IDX=%2d E_IDX=%2d START", M_IDX, C_IDX, FOR_E_IDX);
                    put_bram_weight(M_IDX, C_IDX, `L13_MAP_PT, `L13_MAP_Q, `L13_MAP_R, `L13_SHAPE_C, layer_info);
                    // wait(pass_ready); #1;
                    pass_enable = 1'b1;
                    #(`CYCLE); #1;
                    pass_enable = 1'b0;
                    wait(pass_done); #1;
                    if(C_IDX==(`L13_SHAPE_C/`L13_MAP_QR)-1)begin
                        write_ofmap_back_to_ddr( M_IDX, FOR_E_IDX, OPSUM_ROW_THIS_PASS, `L13_MAP_T, `L13_MAP_P, `L13_MAP_PT, `L13_MAP_E);
                    end
                    $display(" [ INFO] PASS M_IDX=%2d C_IDX=%2d E_IDX=%2d  DONE", M_IDX, C_IDX, FOR_E_IDX);
                end
            end
        end
        write_ddr_ofmap_to_file(layer_info);
        check_ddr_ofmap(layer_info, err);
        if(err)begin
            $display(" [ERROR] L1 OFMAP FAIL !! There are %d error in test patterns.", err);
        end else begin
            $display(" [ INFO] L1 OFMAP PASS !! All ofmap data have been generated successfully!");
        end
        $display(" ================================================================================");
        $display(" [ INFO] L1 Simulation DONE !!!");
        $display(" ================================================================================");
    endtask

    task automatic test_L2();
        $display(" ================================================================================");
        $display(" [ INFO] L2 Simulation Start !!! ");
        $display(" ================================================================================");
        layer_info      = 3'd2;
        layer_enable    = 1'b1;
        #(`CYCLE*1);    #1;
        layer_enable    = 1'b0;
        // initial L2 DDR DATA
        $display(" ================================================================================");
        $display(" [ INFO] READ %s INTO DDR", `L2_IFMAP_DAT);
        $readmemh(`L2_IFMAP_DAT,    IFMAP_DDR);
        $display(" [ INFO] READ %s INTO DDR", `L2_WEIGHT_DAT);
        $readmemh(`L2_WEIGHT_DAT,   L2_WEIGHT_DDR);
        $display(" [ INFO] READ %s INTO DDR", `L2_BIAS_DAT);
        $readmemh(`L2_BIAS_DAT,   L2_BIAS_DDR);
        $display(" ================================================================================");
        // L2 pass for-loop
        for(int FOR_E_IDX=0; FOR_E_IDX <= `L13_E_IDX_LAST; FOR_E_IDX++) begin       // 0~85
            OPSUM_ROW_THIS_PASS = (FOR_E_IDX==`L13_E_IDX_LAST) ? 1 : 3;
            for(int C_IDX=0; C_IDX < (`L13_SHAPE_C/`L13_MAP_QR); C_IDX++) begin     // 0~3
                put_bram_ifmap(FOR_E_IDX, C_IDX, OPSUM_ROW_THIS_PASS, `L13_MAP_E, `L13_MAP_R);
                for(int M_IDX=0; M_IDX<(`L13_SHAPE_M/`L13_MAP_PT); M_IDX++) begin   // 0~7
                    if(C_IDX==0)begin
                        put_bram_bias(M_IDX, `L13_MAP_PT, layer_info);
                    end
                    $display(" ================================================================================");
                    $display(" [ INFO] PASS M_IDX=%2d C_IDX=%2d E_IDX=%2d START", M_IDX, C_IDX, FOR_E_IDX);
                    put_bram_weight(M_IDX, C_IDX, `L13_MAP_PT, `L13_MAP_Q, `L13_MAP_R, `L13_SHAPE_C, layer_info);
                    // wait(pass_ready); #1;
                    pass_enable = 1'b1;
                    #(`CYCLE); #1;
                    pass_enable = 1'b0;
                    wait(pass_done); #1;
                    if(C_IDX==(`L13_SHAPE_C/`L13_MAP_QR)-1)begin
                        write_ofmap_back_to_ddr( M_IDX, FOR_E_IDX, OPSUM_ROW_THIS_PASS, `L13_MAP_T, `L13_MAP_P, `L13_MAP_PT, `L13_MAP_E);
                    end
                    $display(" [ INFO] PASS M_IDX=%2d C_IDX=%2d E_IDX=%2d  DONE", M_IDX, C_IDX, FOR_E_IDX);
                end
            end
        end
        write_ddr_ofmap_to_file(layer_info);
        check_ddr_ofmap(layer_info, err);
        if(err)begin
            $display(" [ERROR] L2 OFMAP FAIL !! There are %d error in test patterns.", err);
        end else begin
            $display(" [ INFO] L2 OFMAP PASS !! All ofmap data have been generated successfully!");
        end
        $display(" ================================================================================");
        $display(" [ INFO] L2 Simulation DONE !!!");
        $display(" ================================================================================");
    endtask

    task automatic test_L3();
        $display(" ================================================================================");
        $display(" [ INFO] L3 Simulation Start !!! ");
        $display(" ================================================================================");
        layer_info      = 3'd3;
        layer_enable    = 1'b1;
        #(`CYCLE*1);    #1;
        layer_enable    = 1'b0;
        // initial L3 DDR DATA
        $display(" ================================================================================");
        $display(" [ INFO] READ %s INTO DDR", `L3_IFMAP_DAT);
        $readmemh(`L3_IFMAP_DAT,    IFMAP_DDR);
        $display(" [ INFO] READ %s INTO DDR", `L3_WEIGHT_DAT);
        $readmemh(`L3_WEIGHT_DAT,   L3_WEIGHT_DDR);
        $display(" [ INFO] READ %s INTO DDR", `L3_BIAS_DAT);
        $readmemh(`L3_BIAS_DAT,   L3_BIAS_DDR);
        $display(" ================================================================================");
        // L3 pass for-loop
        for(int FOR_E_IDX=0; FOR_E_IDX <= `L13_E_IDX_LAST; FOR_E_IDX++) begin       // 0~85
            OPSUM_ROW_THIS_PASS = (FOR_E_IDX==`L13_E_IDX_LAST) ? 1 : 3;
            for(int C_IDX=0; C_IDX < (`L13_SHAPE_C/`L13_MAP_QR); C_IDX++) begin     // 0~3
                put_bram_ifmap(FOR_E_IDX, C_IDX, OPSUM_ROW_THIS_PASS, `L13_MAP_E, `L13_MAP_R);
                for(int M_IDX=0; M_IDX<(`L13_SHAPE_M/`L13_MAP_PT); M_IDX++) begin   // 0~7
                    if(C_IDX==0)begin
                        put_bram_bias(M_IDX, `L13_MAP_PT, layer_info);
                    end
                    $display(" ================================================================================");
                    $display(" [ INFO] PASS M_IDX=%2d C_IDX=%2d E_IDX=%2d START", M_IDX, C_IDX, FOR_E_IDX);
                    put_bram_weight(M_IDX, C_IDX, `L13_MAP_PT, `L13_MAP_Q, `L13_MAP_R, `L13_SHAPE_C, layer_info);
                    // wait(pass_ready); #1;
                    pass_enable = 1'b1;
                    #(`CYCLE); #1;
                    pass_enable = 1'b0;
                    wait(pass_done); #1;
                    if(C_IDX==(`L13_SHAPE_C/`L13_MAP_QR)-1)begin
                        write_ofmap_back_to_ddr( M_IDX, FOR_E_IDX, OPSUM_ROW_THIS_PASS, `L13_MAP_T, `L13_MAP_P, `L13_MAP_PT, `L13_MAP_E);
                    end
                    $display(" [ INFO] PASS M_IDX=%2d C_IDX=%2d E_IDX=%2d  DONE", M_IDX, C_IDX, FOR_E_IDX);
                end
            end
        end
        write_ddr_ofmap_to_file(layer_info);
        check_ddr_ofmap(layer_info, err);
        if(err)begin
            $display(" [ERROR] L3 OFMAP FAIL !! There are %d error in test patterns.", err);
        end else begin
            $display(" [ INFO] L3 OFMAP PASS !! All ofmap data have been generated successfully!");
        end
        $display(" ================================================================================");
        $display(" [ INFO] L3 Simulation DONE !!!");
        $display(" ================================================================================");
    endtask

    task automatic test_L4();
        $display(" ================================================================================");
        $display(" [ INFO] L4 Simulation Start !!! ");
        $display(" ================================================================================");
        layer_info      = 3'd4;
        layer_enable    = 1'b1;
        #(`CYCLE*1);    #1;
        layer_enable    = 1'b0;
        // initial L4 DDR DATA
        $display(" ================================================================================");
        $display(" [ INFO] READ %s INTO DDR", `L4_IFMAP_DAT);
        $readmemh(`L4_IFMAP_DAT,    IFMAP_DDR);
        $display(" [ INFO] READ %s INTO DDR", `L4_WEIGHT_DAT);
        $readmemh(`L4_WEIGHT_DAT,   L4_WEIGHT_DDR);
        $display(" ================================================================================");
        // L4 pass for-loop
        for(int FOR_E_IDX=0; FOR_E_IDX <= `L4_E_IDX_LAST; FOR_E_IDX++) begin
            OPSUM_ROW_THIS_PASS = (FOR_E_IDX==`L4_E_IDX_LAST) ? 4 : 6;
            for(int C_IDX=0; C_IDX < (`L4_SHAPE_C/`L4_MAP_QR); C_IDX++) begin
                put_bram_ifmap(FOR_E_IDX, C_IDX, OPSUM_ROW_THIS_PASS, `L4_MAP_E, `L4_MAP_R);
                for(int M_IDX=0; M_IDX<(`L4_SHAPE_M/`L4_MAP_PT); M_IDX++) begin
                    $display(" ================================================================================");
                    $display(" [ INFO] PASS M_IDX=%2d C_IDX=%2d E_IDX=%2d START", M_IDX, C_IDX, FOR_E_IDX);
                    put_bram_weight(M_IDX, C_IDX, `L4_MAP_PT, `L4_MAP_Q, `L4_MAP_R, `L4_SHAPE_C, layer_info);
                    // wait(pass_ready); #1;
                    pass_enable = 1'b1;
                    #(`CYCLE); #1;
                    pass_enable = 1'b0;
                    wait(pass_done); #1;
                    if(C_IDX==(`L4_SHAPE_C/`L4_MAP_QR)-1)begin
                        write_ofmap_back_to_ddr( M_IDX, FOR_E_IDX, OPSUM_ROW_THIS_PASS, `L4_MAP_T, `L4_MAP_P, `L4_MAP_PT, `L4_MAP_E);
                    end
                    $display(" [ INFO] PASS M_IDX=%2d C_IDX=%2d E_IDX=%2d  DONE", M_IDX, C_IDX, FOR_E_IDX);
                end
            end
        end

        check_ddr_ofmap(layer_info, err);

        if(err)begin
            $display(" [ERROR] L4 OFMAP FAIL !! There are %d error in test patterns.", err);
        end else begin
            $display(" [ INFO] L4 OFMAP PASS !! All ofmap data have been generated successfully!");
        end

        write_ddr_ofmap_to_file(layer_info);

        $display(" ================================================================================");
        $display(" [ INFO] L4 Simulation DONE !!!");
        $display(" ================================================================================");
    endtask

    task automatic copy_ofmap_ddr_to_ifmap_ddr();
        for(int i=0;i<`PAD_IMAGE_SIZE*(`SHAPE_C_MAX/4);i++)
            IFMAP_DDR[i] = OFMAP_DDR[i];
    endtask

    task automatic test_L0_to_L4();

        $display(" ================================================================================");
        $display(" [ INFO] LAYER 0 to 4 Simulation Start !!! ");
        $display(" ================================================================================");
        $display(" ================================================================================");
        $display(" [ INFO] L0 Simulation Start !!! ");
        $display(" ================================================================================");
        layer_info      = 3'd0;
        layer_enable    = 1'b1;
        #(`CYCLE*1);    #1;
        layer_enable    = 1'b0;
        // initial L0 IFMAP WEIGHT DDR DATA
        $display(" ================================================================================");
        $display(" [ INFO] READ %s INTO DDR", `L0_IFMAP_DAT);
        $readmemh(`L0_IFMAP_DAT,    IFMAP_DDR);
        $display(" [ INFO] READ %s INTO DDR", `L0_WEIGHT_DAT);
        $readmemh(`L0_WEIGHT_DAT,   L0_WEIGHT_DDR);
        $display(" ================================================================================");
        // L0 pass for-loop
        for(int FOR_E_IDX=0; FOR_E_IDX <= `L0_E_IDX_LAST; FOR_E_IDX++) begin
            OPSUM_ROW_THIS_PASS = (FOR_E_IDX==`L0_E_IDX_LAST) ? 4 : 6;
            for(int C_IDX=0; C_IDX < `L0_SHAPE_C; C_IDX++) begin
                put_bram_ifmap(FOR_E_IDX, C_IDX, OPSUM_ROW_THIS_PASS, `L0_MAP_E, `L0_MAP_R);
                for(int M_IDX=0; M_IDX<(`L0_SHAPE_M/`L0_MAP_PT); M_IDX++) begin
                    $display(" ================================================================================");
                    $display(" [ INFO] PASS M_IDX=%2d C_IDX=%2d E_IDX=%2d START", M_IDX, C_IDX, FOR_E_IDX);
                    put_bram_weight(M_IDX, C_IDX, `L0_MAP_PT, `L0_MAP_Q, `L0_MAP_R, `L0_SHAPE_C, layer_info);
                    //wait(pass_ready); #1;
                    pass_enable = 1'b1;
                    #(`CYCLE); #1;
                    pass_enable = 1'b0;
                    wait(pass_done); #1;
                    if(C_IDX==`L0_SHAPE_C-1)begin
                        write_ofmap_back_to_ddr( M_IDX, FOR_E_IDX, OPSUM_ROW_THIS_PASS, `L0_MAP_T, `L0_MAP_P, `L0_MAP_PT, `L0_MAP_E);
                    end
                    $display(" [ INFO] PASS M_IDX=%2d C_IDX=%2d E_IDX=%2d  DONE", M_IDX, C_IDX, FOR_E_IDX);
                end
            end
        end
        write_ddr_ofmap_to_file(layer_info);
        $display(" ================================================================================");
        $display(" [ INFO] L0 Simulation DONE !!!");
        $display(" ================================================================================");

        $display(" ================================================================================");
        $display(" [ INFO] COPY L0 OFMAP RESULT FROM OFMAP DDR TO IFMAP DDR");
        copy_ofmap_ddr_to_ifmap_ddr();
        $display(" ================================================================================");

        $display(" ================================================================================");
        $display(" [ INFO] L1 Simulation Start !!! ");
        $display(" ================================================================================");
        layer_info      = 3'd1;
        layer_enable    = 1'b1;
        #(`CYCLE*1);    #1;
        layer_enable    = 1'b0;
        // initial L1 DDR DATA
        $display(" ================================================================================");
        // $display(" [ INFO] READ %s INTO DDR", `L1_IFMAP_DAT);
        // $readmemh(`L1_IFMAP_DAT,    IFMAP_DDR);
        $display(" [ INFO] READ %s INTO DDR", `L1_WEIGHT_DAT);
        $readmemh(`L1_WEIGHT_DAT,   L1_WEIGHT_DDR);
        $display(" [ INFO] READ %s INTO DDR", `L1_BIAS_DAT);
        $readmemh(`L1_BIAS_DAT,   L1_BIAS_DDR);
        $display(" ================================================================================");
        // L1 pass for-loop
        for(int FOR_E_IDX=0; FOR_E_IDX <= `L13_E_IDX_LAST; FOR_E_IDX++) begin       // 0~85
            OPSUM_ROW_THIS_PASS = (FOR_E_IDX==`L13_E_IDX_LAST) ? 1 : 3;
            for(int C_IDX=0; C_IDX < (`L13_SHAPE_C/`L13_MAP_QR); C_IDX++) begin     // 0~3
                put_bram_ifmap(FOR_E_IDX, C_IDX, OPSUM_ROW_THIS_PASS, `L13_MAP_E, `L13_MAP_R);
                for(int M_IDX=0; M_IDX<(`L13_SHAPE_M/`L13_MAP_PT); M_IDX++) begin   // 0~7
                    if(C_IDX==0)begin
                        put_bram_bias(M_IDX, `L13_MAP_PT, layer_info);
                    end
                    $display(" ================================================================================");
                    $display(" [ INFO] PASS M_IDX=%2d C_IDX=%2d E_IDX=%2d START", M_IDX, C_IDX, FOR_E_IDX);
                    put_bram_weight(M_IDX, C_IDX, `L13_MAP_PT, `L13_MAP_Q, `L13_MAP_R, `L13_SHAPE_C, layer_info);
                    // wait(pass_ready); #1;
                    pass_enable = 1'b1;
                    #(`CYCLE); #1;
                    pass_enable = 1'b0;
                    wait(pass_done); #1;
                    if(C_IDX==(`L13_SHAPE_C/`L13_MAP_QR)-1)begin
                        write_ofmap_back_to_ddr( M_IDX, FOR_E_IDX, OPSUM_ROW_THIS_PASS, `L13_MAP_T, `L13_MAP_P, `L13_MAP_PT, `L13_MAP_E);
                    end
                    $display(" [ INFO] PASS M_IDX=%2d C_IDX=%2d E_IDX=%2d  DONE", M_IDX, C_IDX, FOR_E_IDX);
                end
            end
        end
        write_ddr_ofmap_to_file(layer_info);
        // check_ddr_ofmap(layer_info, err);
        // if(err)begin
        //     $display(" [ERROR] L1 OFMAP FAIL !! There are %d error in test patterns.", err);
        // end else begin
        //     $display(" [ INFO] L1 OFMAP PASS !! All ofmap data have been generated successfully!");
        // end
        $display(" ================================================================================");
        $display(" [ INFO] L1 Simulation DONE !!!");
        $display(" ================================================================================");

        $display(" ================================================================================");
        $display(" [ INFO] COPY L1 OFMAP RESULT FROM OFMAP DDR TO IFMAP DDR");
        copy_ofmap_ddr_to_ifmap_ddr();
        $display(" ================================================================================");

        $display(" ================================================================================");
        $display(" [ INFO] L2 Simulation Start !!! ");
        $display(" ================================================================================");
        layer_info      = 3'd2;
        layer_enable    = 1'b1;
        #(`CYCLE*1);    #1;
        layer_enable    = 1'b0;
        // initial L2 DDR DATA
        $display(" ================================================================================");
        $display(" [ INFO] READ %s INTO DDR", `L2_WEIGHT_DAT);
        $readmemh(`L2_WEIGHT_DAT,   L2_WEIGHT_DDR);
        $display(" [ INFO] READ %s INTO DDR", `L2_BIAS_DAT);
        $readmemh(`L2_BIAS_DAT,   L2_BIAS_DDR);
        $display(" ================================================================================");
        // L2 pass for-loop
        for(int FOR_E_IDX=0; FOR_E_IDX <= `L13_E_IDX_LAST; FOR_E_IDX++) begin       // 0~85
            OPSUM_ROW_THIS_PASS = (FOR_E_IDX==`L13_E_IDX_LAST) ? 1 : 3;
            for(int C_IDX=0; C_IDX < (`L13_SHAPE_C/`L13_MAP_QR); C_IDX++) begin     // 0~3
                put_bram_ifmap(FOR_E_IDX, C_IDX, OPSUM_ROW_THIS_PASS, `L13_MAP_E, `L13_MAP_R);
                for(int M_IDX=0; M_IDX<(`L13_SHAPE_M/`L13_MAP_PT); M_IDX++) begin   // 0~7
                    if(C_IDX==0)begin
                        put_bram_bias(M_IDX, `L13_MAP_PT, layer_info);
                    end
                    $display(" ================================================================================");
                    $display(" [ INFO] PASS M_IDX=%2d C_IDX=%2d E_IDX=%2d START", M_IDX, C_IDX, FOR_E_IDX);
                    put_bram_weight(M_IDX, C_IDX, `L13_MAP_PT, `L13_MAP_Q, `L13_MAP_R, `L13_SHAPE_C, layer_info);
                    // wait(pass_ready); #1;
                    pass_enable = 1'b1;
                    #(`CYCLE); #1;
                    pass_enable = 1'b0;
                    wait(pass_done); #1;
                    if(C_IDX==(`L13_SHAPE_C/`L13_MAP_QR)-1)begin
                        write_ofmap_back_to_ddr( M_IDX, FOR_E_IDX, OPSUM_ROW_THIS_PASS, `L13_MAP_T, `L13_MAP_P, `L13_MAP_PT, `L13_MAP_E);
                    end
                    $display(" [ INFO] PASS M_IDX=%2d C_IDX=%2d E_IDX=%2d  DONE", M_IDX, C_IDX, FOR_E_IDX);
                end
            end
        end
        write_ddr_ofmap_to_file(layer_info);
        // check_ddr_ofmap(layer_info, err);
        // if(err)begin
        //     $display(" [ERROR] L2 OFMAP FAIL !! There are %d error in test patterns.", err);
        // end else begin
        //     $display(" [ INFO] L2 OFMAP PASS !! All ofmap data have been generated successfully!");
        // end
        $display(" ================================================================================");
        $display(" [ INFO] L2 Simulation DONE !!!");
        $display(" ================================================================================");

        $display(" ================================================================================");
        $display(" [ INFO] COPY L2 OFMAP RESULT FROM OFMAP DDR TO IFMAP DDR");
        copy_ofmap_ddr_to_ifmap_ddr();
        $display(" ================================================================================");

        $display(" ================================================================================");
        $display(" [ INFO] L3 Simulation Start !!! ");
        $display(" ================================================================================");
        layer_info      = 3'd3;
        layer_enable    = 1'b1;
        #(`CYCLE*1);    #1;
        layer_enable    = 1'b0;
        // initial L3 DDR DATA
        $display(" ================================================================================");
        // $display(" [ INFO] READ %s INTO DDR", `L3_IFMAP_DAT);
        // $readmemh(`L3_IFMAP_DAT,    IFMAP_DDR);
        $display(" [ INFO] READ %s INTO DDR", `L3_WEIGHT_DAT);
        $readmemh(`L3_WEIGHT_DAT,   L3_WEIGHT_DDR);
        $display(" [ INFO] READ %s INTO DDR", `L3_BIAS_DAT);
        $readmemh(`L3_BIAS_DAT,   L3_BIAS_DDR);
        $display(" ================================================================================");
        // L3 pass for-loop
        for(int FOR_E_IDX=0; FOR_E_IDX <= `L13_E_IDX_LAST; FOR_E_IDX++) begin       // 0~85
            OPSUM_ROW_THIS_PASS = (FOR_E_IDX==`L13_E_IDX_LAST) ? 1 : 3;
            for(int C_IDX=0; C_IDX < (`L13_SHAPE_C/`L13_MAP_QR); C_IDX++) begin     // 0~3
                put_bram_ifmap(FOR_E_IDX, C_IDX, OPSUM_ROW_THIS_PASS, `L13_MAP_E, `L13_MAP_R);
                for(int M_IDX=0; M_IDX<(`L13_SHAPE_M/`L13_MAP_PT); M_IDX++) begin   // 0~7
                    if(C_IDX==0)begin
                        put_bram_bias(M_IDX, `L13_MAP_PT, layer_info);
                    end
                    $display(" ================================================================================");
                    $display(" [ INFO] PASS M_IDX=%2d C_IDX=%2d E_IDX=%2d START", M_IDX, C_IDX, FOR_E_IDX);
                    put_bram_weight(M_IDX, C_IDX, `L13_MAP_PT, `L13_MAP_Q, `L13_MAP_R, `L13_SHAPE_C, layer_info);
                    // wait(pass_ready); #1;
                    pass_enable = 1'b1;
                    #(`CYCLE); #1;
                    pass_enable = 1'b0;
                    wait(pass_done); #1;
                    if(C_IDX==(`L13_SHAPE_C/`L13_MAP_QR)-1)begin
                        write_ofmap_back_to_ddr( M_IDX, FOR_E_IDX, OPSUM_ROW_THIS_PASS, `L13_MAP_T, `L13_MAP_P, `L13_MAP_PT, `L13_MAP_E);
                    end
                    $display(" [ INFO] PASS M_IDX=%2d C_IDX=%2d E_IDX=%2d  DONE", M_IDX, C_IDX, FOR_E_IDX);
                end
            end
        end
        write_ddr_ofmap_to_file(layer_info);
        // check_ddr_ofmap(layer_info, err);
        // if(err)begin
        //     $display(" [ERROR] L3 OFMAP FAIL !! There are %d error in test patterns.", err);
        // end else begin
        //     $display(" [ INFO] L3 OFMAP PASS !! All ofmap data have been generated successfully!");
        // end
        $display(" ================================================================================");
        $display(" [ INFO] L3 Simulation DONE !!!");
        $display(" ================================================================================");

        $display(" ================================================================================");
        $display(" [ INFO] COPY L3 OFMAP RESULT FROM OFMAP DDR TO IFMAP DDR");
        copy_ofmap_ddr_to_ifmap_ddr();
        $display(" ================================================================================");

        $display(" ================================================================================");
        $display(" [ INFO] L4 Simulation Start !!! ");
        $display(" ================================================================================");
        layer_info      = 3'd4;
        layer_enable    = 1'b1;
        #(`CYCLE*1);    #1;
        layer_enable    = 1'b0;
        // initial L4 DDR DATA
        $display(" ================================================================================");
        // $display(" [ INFO] READ %s INTO DDR", `L4_IFMAP_DAT);
        // $readmemh(`L4_IFMAP_DAT,    IFMAP_DDR);
        $display(" [ INFO] READ %s INTO DDR", `L4_WEIGHT_DAT);
        $readmemh(`L4_WEIGHT_DAT,   L4_WEIGHT_DDR);
        $display(" ================================================================================");
        // L4 pass for-loop
        for(int FOR_E_IDX=0; FOR_E_IDX <= `L4_E_IDX_LAST; FOR_E_IDX++) begin
            OPSUM_ROW_THIS_PASS = (FOR_E_IDX==`L4_E_IDX_LAST) ? 4 : 6;
            for(int C_IDX=0; C_IDX < (`L4_SHAPE_C/`L4_MAP_QR); C_IDX++) begin
                put_bram_ifmap(FOR_E_IDX, C_IDX, OPSUM_ROW_THIS_PASS, `L4_MAP_E, `L4_MAP_R);
                for(int M_IDX=0; M_IDX<(`L4_SHAPE_M/`L4_MAP_PT); M_IDX++) begin
                    $display(" ================================================================================");
                    $display(" [ INFO] PASS M_IDX=%2d C_IDX=%2d E_IDX=%2d START", M_IDX, C_IDX, FOR_E_IDX);
                    put_bram_weight(M_IDX, C_IDX, `L4_MAP_PT, `L4_MAP_Q, `L4_MAP_R, `L4_SHAPE_C, layer_info);
                    // wait(pass_ready); #1;
                    pass_enable = 1'b1;
                    #(`CYCLE); #1;
                    pass_enable = 1'b0;
                    wait(pass_done); #1;
                    if(C_IDX==(`L4_SHAPE_C/`L4_MAP_QR)-1)begin
                        write_ofmap_back_to_ddr( M_IDX, FOR_E_IDX, OPSUM_ROW_THIS_PASS, `L4_MAP_T, `L4_MAP_P, `L4_MAP_PT, `L4_MAP_E);
                    end
                    $display(" [ INFO] PASS M_IDX=%2d C_IDX=%2d E_IDX=%2d  DONE", M_IDX, C_IDX, FOR_E_IDX);
                end
            end
        end
        // check_ddr_ofmap(layer_info, err);
        // if(err)begin
        //     $display(" [ERROR] L4 OFMAP FAIL !! There are %d error in test patterns.", err);
        // end else begin
        //     $display(" [ INFO] L4 OFMAP PASS !! All ofmap data have been generated successfully!");
        // end
        write_ddr_ofmap_to_file(layer_info);
        $display(" ================================================================================");
        $display(" [ INFO] L4 Simulation DONE !!!");
        $display(" ================================================================================");
    endtask

    // main
    initial begin
        @(negedge clk);
        #(`CYCLE*1);    #1;
        rst             = 1'b0;

        for(int i=0;i<`PAD_IMAGE_SIZE*(`SHAPE_C_MAX/4);i++)begin
            OFMAP_DDR[i] <= 32'h80_80_80_80;
        end

        `ifdef TEST_L0
            test_L0();
        `endif
        `ifdef TEST_L1
            test_L1();
        `endif
        `ifdef TEST_L2
            test_L2();
        `endif
        `ifdef TEST_L3
            test_L3();
        `endif
        `ifdef TEST_L4
            test_L4();
        `endif
        `ifdef TEST_ALL
            test_L0_to_L4();
        `endif
        $display(" ================================================================================");
        $display(" [ INFO] TOTAL USE %e Cycle",cycle_count);
        $display(" [ INFO] TOTAL USE %3.5f Seconds", $itor(cycle_count) * `CYCLE * 1e-9);
        $display(" ================================================================================");
        #(`CYCLE*4); $finish;
    end

    // max cycle
    initial begin
        #(`CYCLE*`END_CYCLE);
        $display(" ================================================================================");
        $display(" [ERROR] Max cycle (%e) reached! Simulation aborted.", `END_CYCLE);
        $display(" ================================================================================");
        $finish;
    end

endmodule
