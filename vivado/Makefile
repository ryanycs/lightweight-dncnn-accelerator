SCRIPTDIR = ./scripts

PROJFILE = .Xil/ .Xiltemp/ NA/ *.srcs/ *.cache/ *.hw/ *.sim/ *.runs/ *.ip_user_files/ *.gen/ *.jou *.xpr *.log output/
PROJFILE_WIN = '.Xil','.Xiltemp','NA','*.srcs','*.cache','*.hw','*.sim','*.runs','*.ip_user_files','*.gen','*.jou','*.xpr','*.log','output/'

ifeq ($(OS), Windows_NT)
	CLEAN = powershell -ExecutionPolicy Bypass -Command "Remove-Item -Path $(PROJFILE_WIN) -Force -Recurse -ErrorAction SilentlyContinue; Out-Null"
else
	CLEAN = rm -rf $(PROJFILE)
endif

all: create_project generate_bitstream

create_project:
	vivado -mode batch -source ${SCRIPTDIR}/create_project.tcl

generate_bitstream:
	vivado -mode batch -source ${SCRIPTDIR}/generate_bitstream.tcl

clean:
	$(CLEAN)