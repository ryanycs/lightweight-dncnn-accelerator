ifeq ($(OS), Windows_NT)
	CLEAN = powershell -ExecutionPolicy Bypass -Command "Remove-Item -Path 'output' -Force -Recurse -ErrorAction SilentlyContinue; Out-Null"
else
	CLEAN = rm -rf output
endif

all: train quantize extract_weights

train:
	python train.py --preprocess

quantize:
	python quantize.py

extract_weights:
	python extract_weights.py

clean:
	@$(CLEAN)