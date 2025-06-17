PROJFILE = .Xil/ .Xiltemp/ NA/ *.srcs/ *.cache/ *.hw/ *.sim/ *.runs/ *.ip_user_files/ *.gen/ *.jou *.xpr *.log
PROJFILE_WIN = '.Xil','.Xiltemp','NA','*.srcs','*.cache','*.hw','*.sim','*.runs','*.ip_user_files','*.gen','*.jou','*.xpr','*.log'

ifeq ($(OS), Windows_NT)
	CLEAN = powershell -ExecutionPolicy Bypass -Command "Remove-Item -Path $(PROJFILE_WIN) -Force -Recurse -ErrorAction SilentlyContinue"
else
	CLEAN = rm -rf $(PROJFILE)
endif

create_project:
	vivado -mode batch -source create_project.tcl

clean:
	$(CLEAN)