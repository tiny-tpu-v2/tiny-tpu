# MNIST Inference Execution Walkthrough

This document explains, step by step, how one inference runs in the finished `de1_soc_mnist_demo`.

The goal is to describe the actual implementation, not a simplified cartoon.

It starts from first principles:

- what the model is computing
- how the image enters the FPGA
- how the scheduler uses the Tiny-TPU datapath
- how the final digit gets latched onto `HEX0`

## 1. What "Inference" Means Here

At a high level, inference means:

1. take a `28x28` digit image
2. convert it into `784` input values
3. run those values through a trained neural network
4. choose the output class with the highest score

The trained network in this project is:

- input layer: `784` values
- hidden layer: `64` neurons
- output layer: `10` neurons

So the model shape is:

```text
784 -> 64 -> 10
```

In plain math:

1. Compute the hidden layer:
   - `hidden = ReLU(input * W1 + B1)`
2. Compute the output layer:
   - `logits = hidden * W2 + B2`
3. Pick the index of the largest logit:
   - `prediction = argmax(logits)`

That `prediction` is the digit shown on the seven-segment display.

## 2. Why This Is Tiled Instead Of "All At Once"

The Tiny-TPU hardware here is not a large accelerator. It is still built around a small `2x2` compute fabric.

That matters because:

- it can only process two input words at a time on the left side
- it can only process two output columns at a time at the top

So the design does **not** load all `784` inputs and all `64` hidden neurons into the TPU at once.

Instead, it breaks the work into many small jobs:

- two input features at a time
- two output neurons at a time

This is called **tiling**.

The main controller in [mnist_classifier_core.v](rtl/mnist_classifier_core.v) performs this tiling explicitly.

Because of that, the unified buffer can stay small:

- the top-level uses `UNIFIED_BUFFER_WIDTH = 128`
- that is enough because each tile job only stages a tiny amount of data at once

This is a critical point:

- the full model is large
- but the **working set per tile** is small
- so the design reuses the same TPU datapath many times

## 3. The Main Blocks Involved

One complete inference uses these blocks in order:

1. [arduino_touch_sender.ino](arduino_touch_sender/arduino_touch_sender.ino)
2. [uart_frame_receiver.v](rtl/uart_frame_receiver.v)
3. [mnist_frame_buffer.v](rtl/mnist_frame_buffer.v)
4. [mnist_uart_ingress.v](rtl/mnist_uart_ingress.v)
5. [mnist_classifier_core.v](rtl/mnist_classifier_core.v)
6. [tpu_mnist.v](rtl/tpu_mnist.v)
7. [de1_soc_mnist_serial_top.v](de1_soc_mnist_serial_top.v)

Each block has a narrow job:

- Arduino builds and sends the frame
- UART logic validates and stores the frame
- classifier core schedules the tiled computation
- Tiny-TPU executes each tile
- top-level latches the final digit to `HEX0`

## 4. Step 0: Before The User Presses Anything

When the FPGA is powered and configured:

- the top-level is clocked from `CLOCK_50`
- `KEY[3]` acts as reset
- the UART RX pin is `UART_RX_IN`
- the classifier waits idle

On reset:

- `frame_loaded_out = 0`
- `digit_valid = 0`
- `busy = 0`
- the hidden buffer is cleared
- the logits buffer is cleared

The trained weights and biases are already available locally inside the FPGA build:

- `W1` from `model/w1_tiled_q8_8.memh`
- `B1` from `model/b1_q8_8.memh`
- `W2` from `model/w2_tiled_q8_8.memh`
- `B2` from `model/b2_q8_8.memh`

The large weight matrices are stored as synchronous ROMs inside [mnist_classifier_core.v](rtl/mnist_classifier_core.v), using `mnist_sync_rom_2r`.

That means:

- the FPGA is not waiting for the Arduino to send weights
- the Arduino only sends the image

## 5. Step 1: The Arduino Creates The Input Frame

On the Arduino:

- the user draws on a `28x28` grid
- each cell is either `0` or `1`
- the firmware uses a thicker brush and stroke interpolation so the drawing is not too sparse

Internally, the Arduino stores the image as:

- `784` binary pixels
- packed into `98` bytes

When the user taps `SEND`, the Arduino transmits:

1. header byte `0xA5`
2. header byte `0x5A`
3. `98` payload bytes
4. one XOR checksum byte

So the wire format is:

```text
[A5] [5A] [98 data bytes] [1 checksum byte]
```

The payload is a packed bitmask:

- bit `0` = pixel `0`
- bit `1` = pixel `1`
- ...
- bit `783` = pixel `783`

This is a compact transport format. It is not sending 784 separate 16-bit values.

## 6. Step 2: The FPGA UART Logic Validates The Frame

The serial input enters [uart_frame_receiver.v](rtl/uart_frame_receiver.v).

That module does four things:

1. waits for the first header byte `0xA5`
2. waits for the second header byte `0x5A`
3. captures exactly `98` payload bytes
4. checks the XOR checksum

Its internal states are:

- `STATE_WAIT_HEADER0`
- `STATE_WAIT_HEADER1`
- `STATE_PAYLOAD`
- `STATE_CHECKSUM`

If the frame is good:

- `frame_valid_out` pulses for one clock

If the frame is bad:

- `frame_error_out` pulses for one clock

If the frame is good, [mnist_frame_buffer.v](rtl/mnist_frame_buffer.v) copies the `784` bits into its local `frame_bits` storage and sets:

- `frame_loaded_out = 1`

That signal stays high until reset.

This is the first useful hardware checkpoint:

- `LEDR[0] = frame_loaded_out`

So `LEDR[0]` turning on means:

- the UART path worked
- the frame header matched
- the checksum matched
- the image is now stored in the FPGA

## 7. Step 3: The Top-Level Accepts One Debounced Start Pulse

The user now presses `KEY[0]` on the DE1-SoC.

The top-level in [de1_soc_mnist_serial_top.v](de1_soc_mnist_serial_top.v) does two important things before it starts inference:

1. it debounces the pushbutton
2. it only allows inference to start if:
   - a frame is already loaded
   - the classifier is not already busy

The actual start condition is:

```text
start_request = start_pulse & frame_loaded_out & ~busy
```

So pressing `KEY[0]` does **nothing** unless the image has already been received.

That is why the correct user order is:

1. draw
2. send
3. wait for `LEDR[0]`
4. press `KEY[0]`

## 8. Step 4: The Classifier Core Starts A New Run

The main inference engine is [mnist_classifier_core.v](rtl/mnist_classifier_core.v).

When `start` arrives in `STATE_IDLE`, it:

- sets `busy = 1`
- clears the hidden buffer
- clears the logits buffer
- clears temporary accumulators
- resets its tile indices
- asserts `tpu_rst`
- moves to `STATE_TILE_PREP`

This starts a fresh inference.

The classifier works in two phases:

1. compute all `64` hidden neurons
2. compute all `10` output logits

The controller tracks which phase it is in with:

- `current_layer = 0` for hidden layer
- `current_layer = 1` for output layer

## 9. Step 5: How One Hidden-Layer Tile Is Computed

This is the core of the design.

A hidden-layer tile computes up to **two hidden neurons** at a time.

For the hidden layer:

- total outputs = `64`
- tile width = `2`
- so there are `32` hidden tiles

Each hidden tile still needs all `784` input features.

But the controller only feeds **two input features at a time** into the TPU.

So each hidden tile is broken into:

- `784 / 2 = 392` input chunks

Each input chunk contributes a partial dot-product for the current two hidden neurons.

### 9.1 Tile preparation

For each hidden tile:

1. `STATE_TILE_PREP`
   - clears the per-tile book-keeping
2. `STATE_RESET_ASSERT`
   - asserts `tpu_rst`
3. `STATE_RESET_RELEASE`
   - deasserts `tpu_rst`

This is deliberate:

- the TPU is used as a short-lived tile engine
- the controller resets it between tile jobs so internal state cannot leak across chunks

### 9.2 Load two input features into the unified buffer

In `STATE_LOAD_INPUT`:

- `pixel_addr_out` points at the next input pixel address
- [mnist_frame_buffer.v](rtl/mnist_frame_buffer.v) returns:
  - `0x0100` for a set pixel
  - `0x0000` for a clear pixel

These values are Q8.8 fixed-point:

- `0x0100` = `1.0`
- `0x0000` = `0.0`

The controller writes those values into the TPU host-write port:

- `ub_wr_host_data_in_0`
- `ub_wr_host_valid_in_0`

At most two input values are written for the current chunk.

### 9.3 Load the matching weights into the unified buffer

In `STATE_LOAD_WEIGHT`, `STATE_LOAD_WEIGHT_WAIT`, and `STATE_LOAD_WEIGHT_COMMIT`:

- the controller calculates the correct addresses into the preloaded weight ROM
- the ROM returns one or two weights
- the controller writes those weights into the unified buffer

For a normal 2-input, 2-output chunk:

- there are `2 x 2 = 4` weights

Those four weights are the weights connecting:

- the current two input features
- to the current two hidden neurons

The weight file is already stored in tile-friendly order, so the controller can fetch the correct four words directly.

### 9.4 Start the TPU weight read

In `STATE_START_WEIGHT`:

- `ub_rd_start_in` pulses
- `ub_ptr_select = 1`
- `ub_rd_transpose = 1`

This tells the unified buffer:

- read the staged weights
- present them in the order the systolic array expects

### 9.5 Start the TPU input read

In `STATE_START_INPUT`:

- `ub_rd_start_in` pulses again
- `ub_ptr_select = 0`
- `ub_rd_transpose = 0`

This tells the unified buffer:

- read the staged input values
- feed them to the left side of the systolic array

### 9.6 Switch the new weights into the active PE registers

In `STATE_SWITCH_WEIGHTS`:

- `sys_switch_in = 1`

This tells the processing elements:

- copy the newly loaded weights into the active weight registers

At that point, the systolic array has:

- the correct two inputs
- the correct four weights

and can execute the chunk.

### 9.7 Wait for the TPU outputs

In `STATE_WAIT_OUTPUT`:

- the controller watches:
  - `vpu_valid_out_1`
  - `vpu_valid_out_2`
- and captures:
  - `vpu_data_out_1`
  - `vpu_data_out_2`

For this MNIST design, the TPU VPU is configured in pure pass-through mode:

- `vpu_data_pathway = 4'b0000`

So in this design:

- the TPU returns raw partial sums
- the controller applies bias and ReLU **outside** the TPU later

That is why the file header in [mnist_classifier_core.v](rtl/mnist_classifier_core.v) says:

- "accumulates raw partial sums externally, then applies bias and ReLU"

Once the chunk outputs have appeared and then gone idle, the controller does:

- `accum_0 += partial_out_0`
- `accum_1 += partial_out_1`

These are saturating 16-bit additions.

So each chunk contributes one more partial sum into the running dot-product for the current two hidden neurons.

### 9.8 Advance to the next input chunk

In `STATE_NEXT_CHUNK`:

- if there are more input features remaining, `chunk_index` increments
- the controller returns to `STATE_TILE_PREP`
- the next two input features are processed

This repeats until all `784` input features have been consumed for the current hidden tile.

## 10. Step 6: Finalize One Hidden Tile

After all `392` chunks for the current hidden tile have finished, the controller enters `STATE_FINALIZE_TILE`.

Now it has the full dot-product results for up to two hidden neurons:

- `accum_0`
- `accum_1`

Only now does it apply:

1. the hidden-layer bias
2. ReLU

Specifically:

```text
hidden = ReLU(accum + B1)
```

Those finalized hidden activations are written into the controller's local hidden buffer:

- `hidden_buffer[...]`

This is important:

- the hidden activations are **not** left inside the TPU
- they are stored in controller-owned memory
- the TPU will be reused for the next tile

Then `STATE_NEXT_TILE` decides:

- move to the next hidden tile, or
- if all hidden tiles are complete, switch to the output layer

## 11. Step 7: Repeat For All 32 Hidden Tiles

The hidden layer has:

- `64` neurons
- tile width `2`

So the controller repeats the hidden-tile process `32` times.

At the end of this phase:

- `hidden_buffer[0..63]` contains the full hidden layer

At that point, the input image is no longer needed for the rest of inference.

## 12. Step 8: Compute The Output Layer

Now `current_layer` switches to `1`.

The controller repeats the same general tile process again, but with different data:

- inputs now come from `hidden_buffer`
- weights now come from `W2`
- biases now come from `B2`

The output layer has:

- `10` neurons
- tile width `2`

So there are:

- `5` output tiles

Each output tile needs all `64` hidden activations.

Because the controller still feeds only two inputs at a time, each output tile is broken into:

- `64 / 2 = 32` chunks

The per-chunk schedule is the same:

1. reset TPU
2. load two hidden activations into the unified buffer
3. load the matching `W2` weights
4. start the weight read
5. start the input read
6. switch weights
7. wait for raw partial sums
8. accumulate them

The difference is in finalization:

- for the output layer, the controller applies only bias
- it does **not** apply ReLU

So the finalize math is:

```text
logit = accum + B2
```

Those results are stored in:

- `logits_buffer[0..9]`

After all five output tiles finish:

- the full set of `10` class logits is available

## 13. Step 9: Run Argmax

Once the output layer is complete, the controller enters:

- `STATE_ARGMAX`
- `STATE_ARGMAX_COMPARE`
- `STATE_ARGMAX_LATCH`

This is the final decision step.

It does not compute any more neural-network math. It simply finds the index of the largest output value.

The sequence is:

1. initialize:
   - `best_index_reg = 0`
   - `best_value = logits_buffer[0]`
2. compare each remaining logit against `best_value`
3. if a larger logit is found:
   - update `best_value`
   - update `best_index_reg`
4. after all 10 logits are checked:
   - `prediction_out <= best_index_reg`

This is implemented as a sequential scan, not a large combinational chain.

That was an intentional timing fix:

- a single big compare chain hurt timing
- the sequential scan closes timing cleanly at `50 MHz`

## 14. Step 10: Mark The Run Complete

When argmax is finished:

- `prediction_out` holds the final digit
- `busy <= 0`
- `done <= 1`

Then the controller moves through `STATE_DONE` and back to `STATE_IDLE`.

This is the end of the actual inference computation.

## 15. Step 11: Latch The Digit Onto HEX0

The top-level in [de1_soc_mnist_serial_top.v](de1_soc_mnist_serial_top.v) watches `done`.

When `done` pulses:

- `latched_digit <= prediction_out`
- `digit_valid <= 1`

Then a small combinational decoder maps the 4-bit digit to the seven-segment pattern for `HEX0`.

So:

- `HEX0` changes only when a completed inference produces `done`
- it does **not** update continuously while the user is drawing

This gives the intended user behavior:

1. draw
2. send
3. press `KEY[0]`
4. wait
5. see one stable predicted digit

## 16. Why The Result Stays Stable

The displayed result stays stable because the top-level uses a latched register:

- `latched_digit`

That register only changes when:

- `done` pulses

So changing the drawing on the Arduino screen does **not** change the FPGA result immediately.

The result only changes after:

1. a new frame is sent
2. `KEY[0]` is pressed
3. the classifier finishes the new run

This is why the demo feels deterministic instead of "continuously recomputing."

## 17. A Concrete Mental Model Of One Full Run

The easiest way to think about one full run is this:

1. The Arduino sends one frozen snapshot of the drawn digit.
2. The FPGA stores that snapshot as `784` binary pixels.
3. The classifier repeatedly asks:
   - "Give me the next two input values."
4. It repeatedly loads:
   - the next two matching weights for the current output pair
5. The Tiny-TPU computes one tiny `2x2` multiply-accumulate job.
6. The controller saves the partial result.
7. This repeats hundreds of times until two hidden neurons are complete.
8. That repeats 32 times until all hidden neurons are complete.
9. Then the same pattern repeats for the output layer.
10. Then the controller chooses the largest logit.
11. The predicted digit is latched onto `HEX0`.

So the FPGA is not doing one giant matrix multiply in one shot.

It is doing:

- many small, controlled TPU jobs
- and stitching them together in the controller

That is the central design idea of this implementation.

## 18. What Signals Tell You Where The Run Is

During hardware bring-up, these are the practical signals to watch:

- `LEDR[0]`
  - the image frame is loaded and valid
- `LEDR[1]`
  - the classifier is currently running
- `LEDR[2]`
  - a prediction is latched and valid
- `LEDR[3]`
  - the UART receiver saw a frame error
- `LEDR[7:4]`
  - the latched predicted digit in binary

And:

- `HEX0`
  - the human-readable predicted digit

That means the real board sequence is:

1. `LEDR[0]` on after `SEND`
2. `LEDR[1]` on during compute
3. `LEDR[2]` on when the result is ready
4. `HEX0` shows the final class

## 19. Why Accuracy Can Still Be Lower Than Software MNIST

Even if the inference path is working perfectly, hardware accuracy can still look worse than the offline test number.

That is because the model is being asked to classify:

- a hand-drawn touchscreen digit

but it was trained on:

- binarized MNIST digits

Those are related, but not identical distributions.

The main mismatch is:

- hand-drawn strokes can be too thin
- they can be off-center
- they can be shaped differently than MNIST digits

That is why the project already improved the Arduino drawing tool with:

- thicker brush strokes
- line interpolation

And the next likely accuracy improvements are:

1. recenter the drawing before sending
2. retrain with touchscreen-like augmentation

## 20. Summary

One inference in this design is:

1. receive one packed binary `28x28` frame over UART
2. store it in the FPGA frame buffer
3. wait for a debounced start pulse
4. run `32` tiled hidden-layer jobs
5. run `5` tiled output-layer jobs
6. run a sequential argmax
7. latch the winning digit to `HEX0`

The critical architectural fact is:

- the Tiny-TPU is used as a small reusable math engine
- the controller around it does the scheduling, chunking, accumulation, biasing, ReLU, and argmax

That is how the design scales a small `2x2` TPU datapath to a full `28x28` MNIST inference without changing the basic TPU fabric.
