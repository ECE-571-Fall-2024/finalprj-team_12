# Welcome to Team-12 Final Project!
## Inferencing Accelerator

AI is going to be everywhere.  We can make it fast and efficient.

This design implements an MNIST handwritten character recognition algorithm

![OIP](https://github.com/user-attachments/assets/e2bc39f2-53fb-459b-b2ee-517627a8ec36)


## What's here

Directories

- [ ] **conv_test**  - unit tests for the convolution layer
- [ ] **cpp**        - C++ support files
- [ ] **data**       - randomly selected digits for testing the full inference
- [ ] **dense_test** - unit tests for the dense layer
- [ ] **max_pool**   - unit tests for the max pooling layer
- [ ] **python**     - python script to testcase data
- [ ] **rtl**        - rtl sources
- [ ] **sim**        - simulation directory, run your simulations here
- [ ] **weights**    - questa memory image files for weights and biases

## How to run things

There are **Makefiles** in the `sim`, `test_conv`, `test_dense`, and `max_pool` directories 

Makefile targets:
- [ ] **clean** - remove created files and cruft
- [ ] **compile** - compile SystemVerilog files, and any needed support files
- [ ] **sim** - compile and run the design in questa command line
- [ ] **gui** - compile and run the deisgn in questa GUI mode
- [ ] **fail** - compile and run with random failures in the design (tests the tests)

### To run the whole enchilada: 

In the **sim** directory execute ` % make sim ` 

### What to expect

There are 20 images in the test stimulus file.  For each image, the testbench will display the input image, then the probabilities for each digit, then the testbench checks to see that the highest probability corresponds to the "label", or correct answer, for the prediction:

<img width="549" alt="Screenshot 2024-12-03 at 8 40 04 AM" src="https://github.com/user-attachments/assets/691dd2a3-5429-455d-8168-3e29dda15c37">

### To run the unit tests

In the test directories for the individual layers, there is a testbench that instantiates just that layer and more throughly execerises the module.  The makefile targets are the same as the main makefile.  In the conv_test there is a "cover" makefile target, runs a simulation with line coverage.

## But, why?

Inferencing requires lots of computations. And CPUs are having a hard time keeping up. Even though this is a **really** small neural network, it takes 2.2 million multiply accumulate operations to compute an inference. Anything that deploys AI is probably going to need some kind of acceleration.  An accelerator could be a GPU, which goes faster than a CPU.  It could be a TPU (tensor processing unit) which goes faster than a GPU. With higher levels of specialization, you get better performance, and usually greater efficiency.

Running these inferences on a RISC-V Rocket core would take about 29 million clocks. Using this accelerator, as configured, takes about 211,000 clocks.  Which is faster.  Not to put too fine a point on it, that's **137 times faster**. (depending on what frequency you can close timing on)

But wait, there's more.  If that isn't fast enough, each later has a parameter that defines the parallelism for the layer.  So, changing one parameter, the number of multipliers can be doubled, which doubles the speed (and the area).  So depending on how much silicon you want to use up, this accelerator can go even faster.

While this is just MNIST, the layers are also configurable for image size and channels.  So these could be the building blocks of a voice recognition inference, facial recognition, object detection, or even automated driving.

![Screenshot 2024-12-03 at 9 50 50 AM](https://github.com/user-attachments/assets/cd2e5989-db57-4341-9dd9-d1a0e9c8867b)

image credit: Ford Motor Company

## Authors and acknowledgment

- [ ] Sai Anurag Kankanala
- [ ] Russell Klein
- [ ] Lohith Kumar Rekapali Naga 

## License
Free to use, but credit the authors

## Project status
It's almost done
