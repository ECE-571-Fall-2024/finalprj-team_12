import mnist_pkg::*;
module tb_max_pool;

  // Parameters
  parameter int ROW_STRIDE    = 2;
  parameter int COL_STRIDE    = 2;
  parameter int IMAGE_HEIGHT  = 4;
  parameter int IMAGE_WIDTH   = 4;
  parameter int CLOCK_PERIOD  = 2;

  // Clock and Reset
  logic clock;
  logic reset_n;

  // Input and output matrices
  feature_type input_image[IMAGE_HEIGHT][IMAGE_WIDTH];
  feature_type output_image[IMAGE_HEIGHT / ROW_STRIDE][IMAGE_WIDTH / COL_STRIDE];
  feature_type expected_output[IMAGE_HEIGHT / ROW_STRIDE][IMAGE_WIDTH / COL_STRIDE];

  // Instantiating the DUT
  max_pool #(
    .ROW_STRIDE(ROW_STRIDE),
    .COL_STRIDE(COL_STRIDE),
    .IMAGE_HEIGHT(IMAGE_HEIGHT),
    .IMAGE_WIDTH(IMAGE_WIDTH)
  ) u_max_pool (
    .clock(clock),
    .reset_n(reset_n),
    .features_in.features[0](input_image[0][0]),  // Connects the input matrix
    .features_out.features[0](output_image[0][0]) // Connects the output matrix
  );

  // Clock
  initial begin
    clock = 0;
    forever #(CLOCK_PERIOD / 2) clock = ~clock;
  end

  // Reset Generation
  initial begin
    reset_n = 0;
    #10 reset_n = 1;
  end

  // Compute Expected Max-Pooling Output
  function automatic void compute_maxpool_output(
    input  feature_type in_image[IMAGE_HEIGHT][IMAGE_WIDTH],
    output feature_type out_image[IMAGE_HEIGHT / ROW_STRIDE][IMAGE_WIDTH / COL_STRIDE]
  );
    for (int row = 0; row < IMAGE_HEIGHT; row += ROW_STRIDE) begin
      for (int col = 0; col < IMAGE_WIDTH; col += COL_STRIDE) begin
        out_image[row / ROW_STRIDE][col / COL_STRIDE] =
          max(max(in_image[row][col], in_image[row][col + 1]),
              max(in_image[row + 1][col], in_image[row + 1][col + 1]));
      end
    end
  endfunction

  // Task to display Matrix
  task automatic display_matrix(
    input feature_type matrix[][], input string label
  );
    $display("%s:", label);
    foreach (matrix[row][col]) begin
      $write("%4d ", matrix[row][col]);
      if (col == $size(matrix[row]) - 1) $write("\n");
    end
  endtask

  // Test Cases
  initial begin
    @(posedge reset_n);

    // Test Case 1: All Zeros
    input_image = '{'{0, 0, 0, 0}, '{0, 0, 0, 0}, '{0, 0, 0, 0}, '{0, 0, 0, 0}};
    compute_maxpool_output(input_image, expected_output);
    #10;
    display_matrix(input_image, "Test Case_1 all_zeros");
    display_matrix(output_image, "Output Image");
    display_matrix(expected_output, "Expected Output");

    if (output_image == expected_output) $display("Test Case 1 Passed!\n");
    else $display("Test Case 1 Failed!\n");

    // Test Case 2: All Ones
    input_image = '{'{1, 1, 1, 1}, '{1, 1, 1, 1}, '{1, 1, 1, 1}, '{1, 1, 1, 1}};
    compute_maxpool_output(input_image, expected_output);
    #10;
    display_matrix(input_image, "Test Case_2 all_ones");
    display_matrix(output_image, "Output Image");
    display_matrix(expected_output, "Expected Output");

    if (output_image == expected_output) $display("Test Case 2 Passed!\n");
    else $display("Test Case 2 Failed!\n");

    // Test Case 3: Increasing Sequence
    input_image = '{
      '{1, 2, 3, 4},
      '{5, 6, 7, 8},
      '{9, 10, 11, 12},
      '{13, 14, 15, 16}
    };
    compute_maxpool_output(input_image, expected_output);
    #10;
    display_matrix(input_image, "Test Case 3 increasing numbers);
    display_matrix(output_image, "Output Image");
    display_matrix(expected_output, "Expected Output");

    if (output_image == expected_output) $display("Test Case 3 Passed!\n");
    else $display("Test Case 3 Failed!\n");

    // Test Case 4: Random Values
    input_image = '{
      '{12, 54, 29, 91},
      '{38, 100, 76, 45},
      '{62, 43, 19, 81},
      '{85, 24, 74, 93}
    };
    compute_maxpool_output(input_image, expected_output);
    #10;
    display_matrix(input_image, "Test Case 4 Random Values)");
    display_matrix(output_image, "Output Image");
    display_matrix(expected_output, "Expected Output");

    if (output_image == expected_output) $display("Test Case 4 Passed!\n");
    else $display("Test Case 4 Failed!\n");

    $finish;
  end

endmodule
`
