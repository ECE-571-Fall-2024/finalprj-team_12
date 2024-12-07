
import mnist_pkg::*;

module dense_testbench;

  parameter INPUT_VECTOR_LENGTH  = 10;
  parameter OUTPUT_VECTOR_LENGTH = 10;
  parameter CLOCK_PERIOD         = 2;
  parameter RESET_PERIOD         = 10;
  parameter NUM_FEATURES         = 2; // Number of features processed per clock cycle

  logic clock;
  logic reset_n;

  initial begin
    clock = 0;
    forever #CLOCK_PERIOD clock = ~clock;
  end

  initial begin
    reset_n = 0;
    repeat (RESET_PERIOD * 2) #CLOCK_PERIOD;
    reset_n = 1;
  end

  feature_type input_vector[INPUT_VECTOR_LENGTH];
  feature_type output_vector[OUTPUT_VECTOR_LENGTH];
  feature_type expected_output[OUTPUT_VECTOR_LENGTH];
  feature_type features_temp[NUM_FEATURES];
  logic features_in_valid, features_out_ready;

  feature_if #(NUM_FEATURES) features_in(), features_out();

  // Function to generate a random vector (static array version)
  function automatic void generate_random_vector(output feature_type vector[INPUT_VECTOR_LENGTH]);
    foreach (vector[i]) begin
      vector[i] = $urandom_range(-256, 255);
    end
  endfunction

  // Compute dense layer output (expected, static array version)
  function automatic void compute_dense_output(
    input feature_type input_vector[INPUT_VECTOR_LENGTH],
    input weight_type weight_memory[],
    input weight_type bias_memory[],
    input int relu_enable,
    output feature_type output_vector[OUTPUT_VECTOR_LENGTH]
  );
    for (int o = 0; o < OUTPUT_VECTOR_LENGTH; o++) begin
      sum_type sum = bias_memory[o];
      for (int i = 0; i < INPUT_VECTOR_LENGTH; i++) begin
        sum += (input_vector[i] * weight_memory[o * INPUT_VECTOR_LENGTH + i]) >>> mnist_pkg::weight_frac_bits;
      end
      if (relu_enable && sum < 0) sum = 0;
      output_vector[o] = sum;
    end
  endfunction

  // Display a vector (static array version)
  task automatic display_vector(input feature_type vector[], input string vector_name);
    $display("%s:", vector_name);
    foreach (vector[i]) $write("%6.3f ", feature_to_real(vector[i]));
    $write("\n");
  endtask

  initial begin
    int i;
    int out_idx;

    // Generate random input vector
    generate_random_vector(input_vector);
    @(posedge reset_n);

    features_in.valid = 0;
    features_out.ready = 0;

    repeat (10) @(posedge clock);

    // Send NUM_FEATURES inputs at a time to the dense module
    features_in.valid = 1;
    i = 0;
    while (i < INPUT_VECTOR_LENGTH) begin
      for (int j = 0; j < NUM_FEATURES; j++) begin
        if (i + j < INPUT_VECTOR_LENGTH)
          features_in.features[j] = input_vector[i + j];
        else
          features_in.features[j] = 0; // Pad with zeros if necessary
      end
      @(posedge clock);
      while (~features_in.ready) @(posedge clock);
      i += NUM_FEATURES;
    end
    features_in.valid = 0;

    // Receive NUM_FEATURES outputs at a time
    features_out.ready = 1;
    i = 0;
    out_idx = 0;
    while (i < OUTPUT_VECTOR_LENGTH) begin
      while (~features_out.valid) @(posedge clock);
      for (int j = 0; j < NUM_FEATURES; j++) begin
        if (out_idx < OUTPUT_VECTOR_LENGTH) begin
          output_vector[out_idx] = features_out.features[j];
          out_idx++;
        end
      end
      i += NUM_FEATURES;
      @(posedge clock);
    end

    // Compute expected output
    compute_dense_output(input_vector, u_dense.weight_memory, u_dense.bias_memory, 1, expected_output);

    // Display results
    display_vector(input_vector, "Input Vector");
    display_vector(output_vector, "DUT Output Vector");
    display_vector(expected_output, "Expected Output Vector");

    // Check if the results match
    if (output_vector == expected_output) begin
      $display("Test Passed!");
    end else begin
      $display("Test Failed!");
    end

    $finish; // End the simulation
  end

  // Instantiate the dense module
  dense #(
    .INPUT_VECTOR_LENGTH(INPUT_VECTOR_LENGTH),
    .OUTPUT_VECTOR_LENGTH(OUTPUT_VECTOR_LENGTH),
    .relu(1),                 // Enable ReLU activation
    .weight_file("weight.mem"), // Weight memory file
    .bias_file("bias.mem")     // Bias memory file
  ) u_dense (
    .clock(clock),
    .reset_n(reset_n),
    .features_in(features_in),
    .features_out(features_out)
  );

endmodule
