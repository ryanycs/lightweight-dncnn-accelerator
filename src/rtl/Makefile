rtlsim:
	vcs -full64 -R -sverilog testfixture.sv -debug_access+all \
	PPU.v \
	PE.v \
	PE_array.v \
	Controller.v \
	+notimingcheck +define+FSDB

clean:
	@rm -f *.fsdb
	@rm -f *.fsdb.lock
	@rm -f *.fsdb.podat
	@rm -f *.fsdb.str
	@rm -f *.conf
	@rm -f *.fsdb.alias
	@rm -f *.fsdb.netwk
	@rm -f *.fsdb.sinf
	@rm -f *.fsdb.tlist
	@rm -f dump.log
	@rm -f *.fsdb.chain
	@rm -f *.fsdb.p2s
	@rm -f *.fsdb.slist
	@rm -f *.fsdb.xlist
	@rm -f ucli.key
	@rm -f *.fsdb.field
	@rm -f *.fsdb.pidat
	@rm -f *.fsdb.slock
	@rm -f simv
	@rm -rf csrc/
	@rm -rf simv.daidir/