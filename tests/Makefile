rtlsim:
	mkdir -p out_dat
	vcs -full64 -R \
	+incdir+../src/rtl \
	-sverilog testfixture.sv  \
	-debug_access+all +notimingcheck \
	+define+TEST_ALL
	python visualize_output.py

clean:
	@rm -f *.fsdb
	@rm -f ucli.key
	@rm -f *.log
	@rm -f simv
	@rm -rf csrc/
	@rm -rf simv.daidir/
	@rm -rf out_dat
