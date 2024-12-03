import mnist_pkg::feature_type;

module testbench;

  // Parameters for the image and pooling dimensions
  parameter IMAGE_HEIGHT  = 4;  
  parameter IMAGE_WIDTH   = 4;
  parameter ROW_STRIDE    = 2;
  parameter COL_STRIDE    = 2;
  parameter OUT_HEIGHT    = IMAGE_HEIGHT / ROW_STRIDE;
  parameter OUT_WIDTH     = IMAGE_WIDTH / COL_STRIDE;

  // Clock and reset signals
  logic clock;
  logic reset_n;

  feature_if features_in();
  feature_if features_out();

  // Interface signals for the DUT
  logic features_in_valid, features_out_ready;
  logic features_out_valid, features_in_ready;
  feature_type features_in_data, features_out_data;

  // Input and output feature maps
  feature_type input_image[IMAGE_HEIGHT][IMAGE_WIDTH];
  feature_type expected_output_image[OUT_HEIGHT][OUT_WIDTH];
  feature_type output_image[OUT_HEIGHT][OUT_WIDTH];

  // Clock generation (10ns period)
  initial begin
    clock = 0;
    forever #5 clock = ~clock;
  end

  // Reset generation
  initial begin
    reset_n = 0;
    #20 reset_n = 1;  // Deassert reset after 20ns
	$display ("Process reset");
  end

  // Instantiate the DUT
  max_pool #(
    .ROW_STRIDE(ROW_STRIDE),
    .COL_STRIDE(COL_STRIDE),
    .IMAGE_HEIGHT(IMAGE_HEIGHT),
    .IMAGE_WIDTH(IMAGE_WIDTH)
  ) u_max_pool (
    .clock(clock),
    .reset_n(reset_n),
    .features_in(features_in),
    .features_out(features_out)
  );

  //Task to load an input image and expected max-pooling result
  task automatic load_image_and_expected_output();
    input_image = '{'{8, 1, 5, 3}, '{6, 7, 2, 4}, '{9, 0, 3, 2}, '{1, 5, 6, 8}};
    expected_output_image = '{'{8, 5}, '{9, 8}};
	$display("Input image: ", input_image);
  endtask

  // Task to drive the input image to the DUT
  task automatic drive_input();
    features_in.valid = 1;
    for (int row = 0; row < IMAGE_HEIGHT; row++) begin
      for (int col = 0; col < IMAGE_WIDTH; col++) begin
        features_in.features[0] = input_image[row][col];
        @(posedge clock);
        while (!features_in.ready) @(posedge clock);
      end
    end
    features_in.valid = 0;
  endtask

  // Task to capture the output from the DUT
  task automatic capture_output();
    @(posedge features_out.valid);
    for (int row = 0; row < OUT_HEIGHT; row++) begin
      for (int col = 0; col < OUT_WIDTH; col++) begin
        output_image[row][col] = features_out.features[0];
        @(posedge clock);
      end
    end
  endtask

  // Task to compare the output with the expected output
  task automatic compare_output();
    int mismatches = 0;
    for (int row = 0; row < OUT_HEIGHT; row++) begin
      for (int col = 0; col < OUT_WIDTH; col++) begin
        if (output_image[row][col] !== expected_output_image[row][col]) begin
          $display("Mismatch at [%0d][%0d]: Expected %d, Got %d",
                   row, col, expected_output_image[row][col], output_image[row][col]);
          mismatches++;
        end
      end
    end

    if (mismatches == 0)
      $display("Test Passed!");
    else
      $display("Test Failed with %d mismatches.", mismatches);
  endtask

  // Task to display input and output images
  task automatic display_images();
    $display("Input Image:");
    for (int row = 0; row < IMAGE_HEIGHT; row++) begin
      for (int col = 0; col < IMAGE_WIDTH; col++) begin
        $write("%3d ", input_image[row][col]);
      end
      $write("\n");
    end

    $display("Expected Output:");
    for (int row = 0; row < OUT_HEIGHT; row++) begin
      for (int col = 0; col < OUT_WIDTH; col++) begin
        $write("%3d ", expected_output_image[row][col]);
      end
      $write("\n");
    end

    $display("DUT Output:");
    for (int row = 0; row < OUT_HEIGHT; row++) begin
      for (int col = 0; col < OUT_WIDTH; col++) begin
        $write("%3d ", output_image[row][col]);
      end
      $write("\n");
    end
  endtask

  // Main Testbench Logic
  initial begin
    load_image_and_expected_output();  // Load image and expected output
    @(posedge reset_n);

    drive_input();  // Drive input to DUT
    capture_output();  // Capture DUT output
    compare_output();  // Compare DUT output with expected
    display_images();  // Display input, expected, and output images

    $finish;  // End simulation
  end

endmodule