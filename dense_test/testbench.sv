import mnist_pkg::*;  
module testbench;

  parameter INPUT_VECTOR_LENGTH  = 10;
  parameter OUTPUT_VECTOR_LENGTH = 10;
  parameter CLOCK_PERIOD         = 2;
  parameter RESET_PERIOD         = 10;

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
  logic        features_in_valid, features_out_ready;

  
  feature_if features_in(), features_out();

  
  function automatic void generate_random_vector(ref feature_type vector[]);
    foreach (vector[i]) begin
      vector[i] = $urandom_range(-256, 255);
    end
  endfunction

  
  function automatic void generate_zero_vector(ref feature_type vector[]);
    foreach (vector[i]) vector[i] = 0; 
  endfunction

  
  function automatic void compute_dense_output(
    input feature_type  input_vector[],
    input weight_type   weight_memory[],
    input weight_type   bias_memory[],
    input int           relu_enable,
    output feature_type output_vector[]
  );
    for (int o = 0; o < OUTPUT_VECTOR_LENGTH; o++) begin
      sum_type sum = bias_memory[o];  
      for (int i = 0; i < INPUT_VECTOR_LENGTH; i++) begin
        sum += (input_vector[i] * weight_memory[o * INPUT_VECTOR_LENGTH + i]) >>> 8;
      end
      
      if (relu_enable && sum < 0) sum = 0;
      output_vector[o] = sum; 
    end
  endfunction

  
  task automatic display_vector(input feature_type vector[], input string vector_name);
    $display("%s:", vector_name);
    foreach (vector[i]) $write("%6.3f ", feature_to_real(vector[i]));
    $write("\n");
  endtask

  
  initial begin
    
    generate_random_vector(input_vector);
    @(posedge reset_n);

    features_in.valid = 0;
    features_out.ready = 0;

    repeat (10) @(posedge clock);

    
    features_in.valid = 1;
    foreach (input_vector[i]) begin
      features_in.features[0] = input_vector[i];
      @(posedge clock);
      while (~features_in.ready) @(posedge clock);  
    end
    features_in.valid = 0; 

    
    features_out.ready = 1;
    foreach (output_vector[i]) begin
      while (~features_out.valid) @(posedge clock);
      output_vector[i] = features_out.features[0];
      @(posedge clock);
    end

    
    compute_dense_output(input_vector, u_dense.weight_memory, u_dense.bias_memory, 1, expected_output);

    
    display_vector(input_vector, "Input Vector");
    display_vector(output_vector, "DUT Output Vector");
    display_vector(expected_output, "Expected Output Vector");

    
    if (output_vector == expected_output) $display("Test Passed!");
    else $display("Test Failed!");

    $finish;  
  end

  
  dense #(
    .INPUT_VECTOR_LENGTH(INPUT_VECTOR_LENGTH),
    .OUTPUT_VECTOR_LENGTH(OUTPUT_VECTOR_LENGTH),
    .relu(1),  // Enable ReLU activation
    .weight_file("weight.mem"),  
    .bias_file("bias.mem")       
  ) u_dense (
    .clock(clock),
    .reset_n(reset_n),
    .features_in(features_in),
    .features_out(features_out)
  );

endmodule

