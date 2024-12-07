
import mnist_pkg::*;

module dense_tb;

  parameter INPUT_VECTOR_LENGTH  = 100;
  parameter OUTPUT_VECTOR_LENGTH = 100;
  parameter clock_period         = 2;
  parameter reset_period         = 10;


  logic clock;
  logic reset_n;

 
  feature_type input_vector[INPUT_VECTOR_LENGTH];
  feature_type output_vector[OUTPUT_VECTOR_LENGTH];
  feature_type expected_output[OUTPUT_VECTOR_LENGTH];
  weight_type weight_memory[OUTPUT_VECTOR_LENGTH][INPUT_VECTOR_LENGTH];
  weight_type bias_memory[OUTPUT_VECTOR_LENGTH];

 
  feature_if features_in();
  feature_if features_out();

  
  dense #(
    .INPUT_VECTOR_LENGTH(INPUT_VECTOR_LENGTH),
    .OUTPUT_VECTOR_LENGTH(OUTPUT_VECTOR_LENGTH),
    .relu(1),
    .weight_file(""), // Not used
    .bias_file("")    // Not used
  ) uut (
    .clock(clock),
    .reset_n(reset_n),
    .features_in(features_in),
    .features_out(features_out)
  );


  initial begin
    clock = 0;
    forever #(clock_period / 2) clock = ~clock;
  end


  initial begin
    reset_n = 0;
    #(reset_period * clock_period);
    reset_n = 1;
    $display("Reset deasserted at time %0t", $time);
  end


  task automatic initialize_weights_and_biases();
    $display("Initializing weights and biases...");
    for (int o = 0; o < OUTPUT_VECTOR_LENGTH; o++) begin
      bias_memory[o] = o;
      for (int i = 0; i < INPUT_VECTOR_LENGTH; i++) begin
        weight_memory[o][i] = i + o; 
      end
    end
  endtask


  task automatic initialize_input_vector();
    $display("Initializing input vector...");
    for (int i = 0; i < INPUT_VECTOR_LENGTH; i++) begin
      input_vector[i] = i; 
    end
  endtask


  task automatic compute_expected_output();
    $display("Computing expected output...");
    for (int o = 0; o < OUTPUT_VECTOR_LENGTH; o++) begin
      feature_type sum = bias_memory[o];
      for (int i = 0; i < INPUT_VECTOR_LENGTH; i++) begin
        sum += (input_vector[i] * weight_memory[o][i]) >>> feature_frac_bits;
      end
      if (sum < 0) sum = '0;
      expected_output[o] = sum;
    end
  endtask


  task automatic drive_inputs();
    $display("Driving inputs to the DUT...");
    features_in.valid = 1;
    for (int i = 0; i < INPUT_VECTOR_LENGTH; i++) begin
      features_in.features[0] = input_vector[i];
      @(posedge clock);
      while (~features_in.ready) @(posedge clock);
    end
    features_in.valid = 0;
  endtask


  task automatic capture_outputs();
    $display("Capturing outputs from the DUT...");
    features_out.ready = 1;
    for (int o = 0; o < OUTPUT_VECTOR_LENGTH; o++) begin
      while (~features_out.valid) @(posedge clock);
      output_vector[o] = features_out.features[0];
      @(posedge clock);
    end
    features_out.ready = 0;
  endtask


  task automatic validate_outputs();
    $display("Validating outputs...");
    for (int o = 0; o < OUTPUT_VECTOR_LENGTH; o++) begin
      if (output_vector[o] !== expected_output[o]) begin
        $display("[ERROR] Output mismatch at index %0d: Expected = %0d, Received = %0d", 
                 o, expected_output[o], output_vector[o]);
      end else begin
        $display("[PASS] Output match at index %0d: Value = %0d", o, output_vector[o]);
      end
    end
  endtask


  initial begin
    $display("=== Starting Dense Module Test ===");
    @(posedge reset_n);
    @(posedge clock);

    initialize_weights_and_biases();
    initialize_input_vector();
    compute_expected_output();
    drive_inputs();
    capture_outputs();
    validate_outputs();
    $display("=== Test Completed ===");
    $finish;
  end

endmodule : dense_tb
