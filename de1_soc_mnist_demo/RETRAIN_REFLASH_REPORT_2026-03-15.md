# Retrain + Reflash Report (2026-03-15)

This report captures the completed model refresh and FPGA deployment using the existing classifier architecture (`784 -> 64 -> 10`).

## Scope

- Keep architecture unchanged.
- Improve robustness through aggressive binary-domain augmentation.
- Retrain/export model artifacts.
- Rebuild Quartus image with new weights.
- Reflash DE1-SoC FPGA.
- Produce benchmark artifacts from synthetic hand-drawn digits.

## Model Training Run

Command used:

```bash
cd de1_soc_mnist_demo
../.venv-mnist/bin/python train_mnist.py \
  --hidden-size 64 \
  --split-mode balanced \
  --train-limit 50000 \
  --test-limit 8000 \
  --max-iter 80 \
  --augment-mode extreme \
  --augment-copies 1 \
  --output-dir model \
  --seed 7
```

Result summary (from `model/summary.json`):

- `input_size`: `784`
- `hidden_size`: `64`
- `output_size`: `10`
- `tile_width`: `2`
- `split_mode`: `balanced`
- `train_limit`: `50000`
- `test_limit`: `8000`
- `augment_mode`: `extreme`
- `augment_copies`: `1`
- `effective_train_samples`: `100000`
- `accuracy`: `0.954375`

Important generated model artifacts:

- `model/w1_tiled_q8_8.memh`
- `model/b1_q8_8.memh`
- `model/w2_tiled_q8_8.memh`
- `model/b2_q8_8.memh`
- `model/summary.json`

## FPGA Build + Flash

Build command:

```bash
cd de1_soc_mnist_demo
bash build_quartus.sh
```

Programming command:

```bash
cd de1_soc_mnist_demo
bash program_fpga.sh
```

Observed issue during flash:

- First program attempt failed with:
  - `Error (209042): Application SystemConsole on 127.0.0.1 is using the target device`
- Resolution:
  - terminate System Console process
  - rerun `bash program_fpga.sh`
- Second program attempt succeeded with:
  - `Configuration succeeded -- 1 device(s) configured`
  - `Quartus Prime Programmer was successful. 0 errors, 0 warnings`

Updated FPGA artifacts:

- `artifacts_jtag/de1_soc_mnist_jtag_top.sof`
- `artifacts_jtag/de1_soc_mnist_jtag_top.fit.rpt`
- `artifacts_jtag/de1_soc_mnist_jtag_top.flow.rpt`
- `artifacts_jtag/de1_soc_mnist_jtag_top.asm.rpt`
- `artifacts_jtag/de1_soc_mnist_jtag_top.map.rpt`
- `artifacts_jtag/de1_soc_mnist_jtag_top.merge.rpt`

## Synthetic Hand-Drawn Benchmark

Command used:

```bash
cd de1_soc_mnist_demo
../.venv-mnist/bin/python tools/benchmark_synthetic_handdrawn.py \
  --samples-per-digit 120 \
  --preview-per-digit 4 \
  --seed 1234
```

Artifact folder:

- `synthetic_handdrawn_benchmark/`

Primary outputs:

- `synthetic_handdrawn_benchmark/results.json`
- `synthetic_handdrawn_benchmark/predictions.csv`
- `synthetic_handdrawn_benchmark/previews/`

Recorded result:

- overall synthetic stress-test accuracy: `0.4700` (`564/1200`)
- strongest digits in this run: `0`, `7`
- weakest digits in this run: `6`, `8`, `4`

## One-Command Startup

Use this startup wrapper from the project directory:

```bash
bash start_mnist_demo.sh
```

The wrapper delegates to `quickstart_jtag_demo.sh` and supports pass-through flags such as:

```bash
bash start_mnist_demo.sh --help
bash start_mnist_demo.sh --build
bash start_mnist_demo.sh --no-loop
bash start_mnist_demo.sh --no-verify-writeback
```
