ifeq ($(OS), Windows_NT)
	CLEAN = powershell -ExecutionPolicy Bypass -Command "Remove-Item -Path 'build' -Force -Recurse -ErrorAction SilentlyContinue; Out-Null"
else
	CLEAN = rm -rf build
endif

help:
	@echo "Makefile for Lightweight DnCNN Accelerator"
	@echo ""
	@echo "  make train        - Train the DnCNN model"
	@echo "  make quantize     - Quantize the model and extract weights"
	@echo "  make synth        - Synthesize the design and generate bitstream"
	@echo "  make build        - Package .bit/.hwh, data, and notebook for PYNQ"
	@echo "  make clean        - Clean up generated files and directories"

all: train quantize synth build

train:
	python model/train.py --preprocess

quantize:
	python model/quantize.py
	python model/extract_weights.py

synth:
	cd vivado && make

build:
	python scripts/build.py

clean:
	cd model && make clean
	cd vivado && make clean
	cd tests && make clean
	@$(CLEAN)