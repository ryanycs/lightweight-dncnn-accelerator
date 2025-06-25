# set_false_path -from [get_clocks clk_fpga_1] -to [get_clocks clk_fpga_0]


set_multicycle_path -from [get_pins {design_1_i/Controller_u/inst/layer_info_reg_reg[1]/C}] -to [get_pins {design_1_i/blk_mem_gen_0/U0/inst_blk_mem_gen/gnbram.gnative_mem_map_bmg.native_mem_map_blk_mem_gen/valid.cstr/ramloop[*].ram.r/prim_noinit.ram/DEVICE_7SERIES.WITH_BMM_INFO.TRUE_DP.CASCADED_PRIM36.ram_T/DIBDI[0]}] 5
set_multicycle_path -from [get_pins {design_1_i/Controller_u/inst/layer_info_reg_reg[0]/C}] -to [get_pins {design_1_i/blk_mem_gen_0/U0/inst_blk_mem_gen/gnbram.gnative_mem_map_bmg.native_mem_map_blk_mem_gen/valid.cstr/ramloop[*].ram.r/prim_noinit.ram/DEVICE_7SERIES.WITH_BMM_INFO.TRUE_DP.CASCADED_PRIM36.ram_T/DIBDI[0]}] 5
set_false_path -from [get_pins {design_1_i/Controller_u/inst/layer_info_reg_reg[1]/C}] -to [get_pins {design_1_i/blk_mem_gen_0/U0/inst_blk_mem_gen/gnbram.gnative_mem_map_bmg.native_mem_map_blk_mem_gen/valid.cstr/ramloop[*].ram.r/prim_noinit.ram/DEVICE_7SERIES.WITH_BMM_INFO.TRUE_DP.CASCADED_PRIM36.ram_B/DIBDI[0]}]
set_multicycle_path -from [get_pins {design_1_i/Controller_u/inst/layer_info_reg_reg[0]/C}] -to [get_pins {design_1_i/blk_mem_gen_0/U0/inst_blk_mem_gen/gnbram.gnative_mem_map_bmg.native_mem_map_blk_mem_gen/valid.cstr/ramloop[*].ram.r/prim_noinit.ram/DEVICE_7SERIES.WITH_BMM_INFO.TRUE_DP.CASCADED_PRIM36.ram_B/DIBDI[0]}] 5
