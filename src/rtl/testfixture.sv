`timescale 1ns/10ps
`include "define.svh"

`define CYCLE               10.0
`define END_CYCLE           6000000000

`define BRAM_SIZE           (2**17)
`define IMAGE_SIZE          (256*256)
`define PAD_IMAGE_SIZE      (258*256)
`define KERNEL_SIZE         ( 9)

`define SHAPE_C_MAX         (64)
`define SHAPE_M_MAX         (64)

// L0
`define L0_SHAPE_C          ( 1)
`define L0_SHAPE_M          (64)
`define L0_MAP_M            (64)
`define L0_MAP_P            ( 4)
`define L0_MAP_T            ( 4)
`define L0_MAP_PT           (16)
`define L0_MAP_E            ( 6)
`define L0_MAP_Q            ( 1)
`define L0_MAP_R            ( 1)
`define L0_E_IDX_LAST       (42)
`define L0_IFMAP_DAT        "./dat/layer0_dat/layer0_input_image_pad.hex"
`define L0_WEIGHT_DAT       "./dat/layer0_dat/layer0_weight.hex"
`define L0_OFMAP_DAT        "./dat/layer0_dat/layer0_opsum_golden.hex"

// L13
`define L13_SHAPE_C         (64)
`define L13_SHAPE_M         (64)
`define L13_MAP_M           (64)
`define L13_MAP_P           ( 4)
`define L13_MAP_T           ( 2)
`define L13_MAP_PT          ( 8)
`define L13_MAP_E           ( 3)
`define L13_MAP_Q           ( 4)
`define L13_MAP_R           ( 4)
`define L13_MAP_QR          (16)
`define L13_E_IDX_LAST      (85)

// L1
`define L1_IFMAP_DAT        "./dat/layer1_dat/layer1_input_pad.hex"
`define L1_WEIGHT_DAT       "./dat/layer1_dat/layer1_weight.hex"
`define L1_OFMAP_DAT        "./dat/layer1_dat/layer1_golden.hex"

// L4
`define L4_SHAPE_C         (64)
`define L4_SHAPE_M         ( 1)
`define L4_MAP_M           ( 1)
`define L4_MAP_P           ( 1)
`define L4_MAP_T           ( 1)
`define L4_MAP_PT          ( 1)
`define L4_MAP_E           ( 6)
`define L4_MAP_Q           ( 4)
`define L4_MAP_R           ( 4)
`define L4_E_IDX_LAST      (42)
`define L4_WEIGHT_DAT      ""

module testfixture;

    // logic [31:0] INPUT_IMAGE    [0 : `PAD_IMAGE_SIZE * `L0_SHAPE_C - 1];
    // logic [31:0] INPUT_WEIGHT   [0 : `L0_SHAPE_M * `L0_SHAPE_C * `KERNEL_SIZE - 1];

    logic [31:0] BRAM_DATA      [0 : `BRAM_SIZE-1];
    logic [31:0] OPSUM_GOLDEN   [0 : `IMAGE_SIZE * (`SHAPE_C_MAX/4) - 1];

    logic [31:0] L0_WEIGT_DDR   [0 : `L0_SHAPE_M  * `L0_SHAPE_C  * `KERNEL_SIZE - 1];
    logic [31:0] L1_WEIGT_DDR   [0 : `L13_SHAPE_M * `L13_SHAPE_C * `KERNEL_SIZE - 1];
    logic [31:0] L2_WEIGT_DDR   [0 : `L13_SHAPE_M * `L13_SHAPE_C * `KERNEL_SIZE - 1];
    logic [31:0] L3_WEIGT_DDR   [0 : `L13_SHAPE_M * `L13_SHAPE_C * `KERNEL_SIZE - 1];
    logic [31:0] L4_WEIGT_DDR   [0 : `L4_SHAPE_M  * `L4_SHAPE_C  * `KERNEL_SIZE - 1];

    logic [31:0] IFMAP_DDR      [0 : `PAD_IMAGE_SIZE * (`SHAPE_C_MAX/4) - 1];
    logic [31:0] OFMAP_DDR      [0 : `PAD_IMAGE_SIZE * (`SHAPE_C_MAX/4) - 1];

    logic           rst             = 1;
    logic           clk             = 0;
    logic [1:0]     layer_info      = 2'b00;
    logic           layer_enable    = 1'b0;
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
    int             cycle_count;
    int             error_cnt, total_err, err;

    int             error_flag;
    int             opsum_golden_addr;
    int             opsum_bram_addr;

    int             ifmap_ddr_addr;
    int             ifmap_bram_addr;

    int             weight_ddr_addr;
    int             weight_bram_addr;

    int             OPSUM_ROW_THIS_PASS;

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
            for(int i=0;i<`BRAM_SIZE;i++)   BRAM_DATA[i] <= 32'd0;
        end begin
            // read a ===================================================================
            if (~|bram_b_web)
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
                else if (bram_b_web[i])
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
        cycle_count <= rst ? 0 : cycle_count + 1;
    end

    // ---------- OPSUM compare -----------
    task automatic check_opsum(input int M_IDX, input int E_IDX, input int OPSUM_ROW, input int MAP_T, input int MAP_P, input int MAP_PT, input int MAP_E, output int err);
        err = 0;
        for (int TT = 0; TT < MAP_T; TT++) begin
            for (int EE = 0; EE < OPSUM_ROW; EE++) begin
                for (int FF = 0; FF < 256; FF++) begin
                    error_flag          = 0;
                    opsum_golden_addr   =                           ((M_IDX * MAP_T  + TT) *     `IMAGE_SIZE) + ((E_IDX * MAP_E + EE) * 256) + (FF);
                    opsum_bram_addr     = (`GLB_OPADDR_OFFSET/4) +  ((M_IDX * MAP_PT + TT) * OPSUM_ROW * 256) + ((                EE) * 256) + (FF);
                    expect_data         = OPSUM_GOLDEN[opsum_golden_addr];
                    real_data           = BRAM_DATA[opsum_bram_addr];
                    for (int PP = 0; PP < MAP_P; PP++)
                        if (!((expect_data[PP*8+:8] === real_data[PP*8+:8]) || (expect_data[PP*8+:8] === real_data[PP*8+:8]-1)))begin
                            err++;
                            error_flag = 1;
                        end
                    if (error_flag) begin
                        $display(" [ERROR] BRAM ADDR: %d", opsum_bram_addr*4);
                        $display(" [ERROR] M_IDX:%2d E_IDX:%2d OPSUM[%2d][%2d][%2d] mismatch exp=%8h get=%8h", M_IDX, E_IDX, TT, EE, FF, expect_data, real_data);
                    end
                end
            end
        end
    endtask

    // ---------- BRAM put ifmap ----------
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

    // ---------- BRAM put weight ---------
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
                        0:  bram_a_din          = L0_WEIGT_DDR[weight_ddr_addr];
                        1:  bram_a_din          = L1_WEIGT_DDR[weight_ddr_addr];
                        2:  bram_a_din          = L2_WEIGT_DDR[weight_ddr_addr];
                        3:  bram_a_din          = L3_WEIGT_DDR[weight_ddr_addr];
                        4:  bram_a_din          = L4_WEIGT_DDR[weight_ddr_addr];
                    endcase

                    @(negedge clk);
                end
            end
        end
        bram_a_web      = 4'b0000;
    endtask

    task automatic test_L0();
        $display(" ================================================================================");
        $display(" [ INFO] L0 Simulation Start !!! ");
        $display(" ================================================================================");
        layer_info      = 2'b00;
        layer_enable    = 1'b1;
        #(`CYCLE*1);    #1;
        layer_enable    = 1'b0;
        total_err       = 0;

        // initial L0 DDR DATA
        $display(" ================================================================================");
        $display(" [ INFO] READ %s INTO DDR", `L0_IFMAP_DAT);
        $readmemh(`L0_IFMAP_DAT,    IFMAP_DDR);
        $display(" [ INFO] READ %s INTO DDR", `L0_WEIGHT_DAT);
        $readmemh(`L0_WEIGHT_DAT,   L0_WEIGT_DDR);
        $display(" [ INFO] READ %s INTO GOLDEN BUFFER", `L0_OFMAP_DAT);
        $readmemh(`L0_OFMAP_DAT,    OPSUM_GOLDEN);
        $display(" ================================================================================");

        // L0 pass for-loop
        for(int FOR_E_IDX=0; FOR_E_IDX <= `L0_E_IDX_LAST; FOR_E_IDX++) begin
            OPSUM_ROW_THIS_PASS = (FOR_E_IDX==`L0_E_IDX_LAST) ? 4 : 6;
            for(int C_IDX=0; C_IDX < `L0_SHAPE_C; C_IDX++) begin
                // $display(" ================================================================================");
                // $display(" [ INFO] READ IFMAP  C_IDX=%2d E_IDX=%2d FROM DDR TO BRAM START (Total %2d rows)", C_IDX, FOR_E_IDX, (OPSUM_ROW_THIS_PASS+2));
                put_bram_ifmap(FOR_E_IDX, C_IDX, OPSUM_ROW_THIS_PASS, `L0_MAP_E, `L0_MAP_R);
                // $display(" [ INFO] READ IFMAP  C_IDX=%2d E_IDX=%2d FROM DDR TO BRAM  DONE (Total %2d rows)", C_IDX, FOR_E_IDX, (OPSUM_ROW_THIS_PASS+2));
                // $display(" ================================================================================");
                for(int M_IDX=0; M_IDX<(`L0_SHAPE_M/`L0_MAP_PT); M_IDX++) begin
                    $display(" ================================================================================");
                    $display(" [ INFO] PASS M_IDX=%2d C_IDX=%2d E_IDX=%2d START", M_IDX, C_IDX, FOR_E_IDX);
                    // $display(" [ INFO] READ WEIGHT M_IDX=%2d C_IDX=%2d FROM DDR TO BRAM START", M_IDX, C_IDX);
                    put_bram_weight(M_IDX, C_IDX, `L0_MAP_PT, `L0_MAP_Q, `L0_MAP_R, `L0_SHAPE_C, 0);
                    // $display(" [ INFO] READ WEIGHT M_IDX=%2d C_IDX=%2d FROM DDR TO BRAM  DONE", M_IDX, C_IDX);
                    // $display(" ================================================================================");
                    //wait(pass_ready); #1;
                    pass_enable = 1'b1;
                    #(`CYCLE); #1;
                    pass_enable = 1'b0;
                    wait(pass_done); #1;
                    if(C_IDX==`L0_SHAPE_C-1)begin
                        error_cnt = 0;
                        $display(" [ INFO] Checking opsum result..");
                        check_opsum(M_IDX, FOR_E_IDX, OPSUM_ROW_THIS_PASS, `L0_MAP_T, `L0_MAP_P, `L0_MAP_PT, `L0_MAP_E, err);
                        error_cnt = err;
                        total_err += error_cnt;
                        if(error_cnt)begin
                            $display(" [ERROR] OPSUM FAIL !! There are %d error in test patterns.", error_cnt);
                        end else begin
                            $display(" [ INFO] OPSUM PASS !! All opsum data have been generated successfully! ");
                        end
                    end
                    // $display(" [ INFO] PASS M_IDX=%0d C_IDX=%0d E_IDX=%0d  DONE", M_IDX, C_IDX, FOR_E_IDX);
                    $display(" ================================================================================");
                    if(error_cnt)begin
                        #(`CYCLE*4); $finish;
                    end
                end
            end
        end
        if (total_err)
            $display(" [ERROR] Total mismatch = %0d error in test patterns.", total_err);
        else
            $display(" [ INFO] L0 All passes PASS!");

        $display(" ================================================================================");
        $display(" [ INFO] print L0 last pass last row opsum start");
        for(int f=0; f<256; f++)begin                               // (M*pt + t) * e_this_pass + e*256 + f
            opsum_bram_addr     = (`GLB_OPADDR_OFFSET/4) +  ((3 * `L0_MAP_PT + 3) * 4 * 256) + (3 * 256) + (f);
            $display(" opsum last pass last row [%0d][%0d][%0d] = %8X",63 , 255 , f, BRAM_DATA[opsum_bram_addr]);
        end
        $display(" [ INFO] print L0 last pass last row opsum done ");
        $display(" ================================================================================");
        $display(" ================================================================================");
        $display(" [ INFO] L0 Simulation DONE !!!");
        $display(" ================================================================================");
    endtask

    task automatic test_L1();
        $display(" ================================================================================");
        $display(" [ INFO] L1 Simulation Start !!! ");
        $display(" ================================================================================");
        layer_info      = 2'b01;
        layer_enable    = 1'b1;
        #(`CYCLE*1);    #1;
        layer_enable    = 1'b0;
        total_err       = 0;

        // initial L1 DDR DATA
        $display(" ================================================================================");
        $display(" [ INFO] READ %s INTO DDR", `L1_IFMAP_DAT);
        $readmemh(`L1_IFMAP_DAT,    IFMAP_DDR);
        $display(" [ INFO] READ %s INTO DDR", `L1_WEIGHT_DAT);
        $readmemh(`L1_WEIGHT_DAT,   L1_WEIGT_DDR);
        $display(" [ INFO] READ %s INTO GOLDEN BUFFER", `L1_OFMAP_DAT);
        $readmemh(`L1_OFMAP_DAT,    OPSUM_GOLDEN);
        $display(" ================================================================================");

        // L1 pass for-loop
        for(int FOR_E_IDX=0; FOR_E_IDX <= `L13_E_IDX_LAST; FOR_E_IDX++) begin
            OPSUM_ROW_THIS_PASS = (FOR_E_IDX==`L13_E_IDX_LAST) ? 1 : 3;
            for(int C_IDX=0; C_IDX < (`L13_SHAPE_C/`L13_MAP_QR); C_IDX++) begin
                // $display(" ================================================================================");
                // $display(" [ INFO] READ IFMAP  C_IDX=%2d E_IDX=%2d FROM DDR TO BRAM START (Total %2d rows)", C_IDX, FOR_E_IDX, (OPSUM_ROW_THIS_PASS+2));
                put_bram_ifmap(FOR_E_IDX, C_IDX, OPSUM_ROW_THIS_PASS, `L13_MAP_E, `L13_MAP_R);
                // $display(" [ INFO] READ IFMAP  C_IDX=%2d E_IDX=%2d FROM DDR TO BRAM  DONE (Total %2d rows)", C_IDX, FOR_E_IDX, (OPSUM_ROW_THIS_PASS+2));
                // $display(" ================================================================================");
                for(int M_IDX=0; M_IDX<(`L13_SHAPE_M/`L13_MAP_PT); M_IDX++) begin
                    $display(" ================================================================================");
                    $display(" [ INFO] PASS M_IDX=%2d C_IDX=%2d E_IDX=%2d START", M_IDX, C_IDX, FOR_E_IDX);
                    // $display(" [ INFO] READ WEIGHT M_IDX=%2d C_IDX=%2d FROM DDR TO BRAM START", M_IDX, C_IDX);
                    put_bram_weight(M_IDX, C_IDX, `L13_MAP_PT, `L13_MAP_Q, `L13_MAP_R, `L13_SHAPE_C, 1);    ///////////////////////////////////////////////////
                    // $display(" [ INFO] READ WEIGHT M_IDX=%2d C_IDX=%2d FROM DDR TO BRAM  DONE", M_IDX, C_IDX);
                    // $display(" ================================================================================");
                    wait(pass_ready); #1;
                    pass_enable = 1'b1;
                    #(`CYCLE); #1;
                    pass_enable = 1'b0;
                    wait(pass_done); #1;
                    if(C_IDX==(`L13_SHAPE_C/`L13_MAP_QR)-1)begin
                        error_cnt = 0;
                        $display(" [ INFO] Checking opsum result..");
                        check_opsum(M_IDX, FOR_E_IDX, OPSUM_ROW_THIS_PASS, `L13_MAP_T, `L13_MAP_P, `L13_MAP_PT, `L13_MAP_E, err);
                        error_cnt = err;
                        total_err += error_cnt;
                        if(error_cnt)begin
                            $display(" [ERROR] OPSUM FAIL !! There are %d error in test patterns.", error_cnt);
                        end else begin
                            $display(" [ INFO] OPSUM PASS !! All opsum data have been generated successfully! ");
                        end
                    end
                    // $display(" [ INFO] PASS M_IDX=%0d C_IDX=%0d E_IDX=%0d  DONE", M_IDX, C_IDX, FOR_E_IDX);
                    $display(" ================================================================================");
                    if(error_cnt)begin
                        #(`CYCLE*4); $finish;
                    end
                end
            end
        end
        if (total_err)
            $display(" [ERROR] Total mismatch = %0d error in test patterns.", total_err);
        else
            $display(" [ INFO] L1 All passes PASS!");

        $display(" ================================================================================");
        $display(" [ INFO] print L1 last pass last row opsum start");
        for(int f=0; f<256; f++)begin                               // (M*pt + t) * e_this_pass + e*256 + f
            opsum_bram_addr     = (`GLB_OPADDR_OFFSET/4) +  ((3 * `L13_MAP_PT + 3) * 4 * 256) + (3 * 256) + (f);
            $display(" opsum last pass last row [%0d][%0d][%0d] = %8X",63 , 255 , f, BRAM_DATA[opsum_bram_addr]);
        end
        $display(" [ INFO] print L1 last pass last row opsum done ");
        $display(" ================================================================================");
        $display(" ================================================================================");
        $display(" [ INFO] L1 Simulation DONE !!!");
        $display(" ================================================================================");
    endtask

    initial begin

        @(negedge clk);
        #(`CYCLE*1);    #1;
        rst             = 1'b0;

        //test_L0();

        test_L1();

        // $display(" ================================================================================");
        // $display(" [ INFO] print last pass opsum info start");
        // $display(" ================================================================================");
        //     for(int t =0; t<4; t++)
        //         for(int e =0; e<4; e++)
        //             for(int f=0; f<256; f++)begin
        //                 opsum_bram_addr     = (`GLB_OPADDR_OFFSET/4) +  ((3 * `L0_MAP_PT + t) * 4 * 256) + ((e) * 256) + (f);
        //                 $display(" opsum last pass [%0d][%0d][%0d] = %8X", t,e,f, BRAM_DATA[opsum_bram_addr]);
        //             end
        // $display(" ================================================================================");
        // $display(" [ INFO] print last pass opsum info done ");
        // $display(" ================================================================================");

        $display(" ================================================================================");
        $display(" [ INFO] TOTAL USE %d Cycle", cycle_count);
        $display(" ================================================================================");
        #(`CYCLE*4); $finish;
    end


    // max cycle
    initial begin
        #(`CYCLE*`END_CYCLE);
        $display(" ================================================================================");
        $display(" [ERROR] Max cycle (%d) reached! Simulation aborted.", `END_CYCLE);
        $display(" ================================================================================");
        $finish;
    end

endmodule
