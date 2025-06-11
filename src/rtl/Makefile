rtlsim:
	vcs -full64 -R -sverilog testfixture.sv -debug_access+all \
	PPU.v \
	PE.v \
	PE_array.v \
	Controller.v \
	+notimingcheck +define+FSDB

clean:
	@rm -f *.fsdb
	@rm -f ucli.key
	@rm -f *.log
	@rm -f simv
	@rm -rf csrc/
	@rm -rf simv.daidir/
