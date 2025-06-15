rtlsim:
	mkdir -p out_dat
	vcs -full64 -R -sverilog testfixture.sv -debug_access+all \
	PPU.v \
	PE.v \
	PE_array.v \
	Controller.v \
	+notimingcheck +define+TEST_ALL

clean:
	@rm -f *.fsdb
	@rm -f ucli.key
	@rm -f *.log
	@rm -f simv
	@rm -rf csrc/
	@rm -rf simv.daidir/
	@rm -rf out_dat
