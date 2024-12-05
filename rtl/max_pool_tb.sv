import mnist_pkg::feature_type;

module max_pool_tb;

  parameter IMAGE_HEIGHT  = 4;  
  parameter IMAGE_WIDTH   = 4;
  parameter ROW_STRIDE    = 2;
  parameter COL_STRIDE    = 2;
  parameter OUT_HEIGHT    = IMAGE_HEIGHT / ROW_STRIDE;
  parameter OUT_WIDTH     = IMAGE_WIDTH / COL_STRIDE;

  logic clock;
  logic reset_n;

  feature_if features_in();
  feature_if features_out();

  feature_type input_image[IMAGE_HEIGHT][IMAGE_WIDTH];
  feature_type expected_output_image[OUT_HEIGHT][OUT_WIDTH];
  feature_type output_image[OUT_HEIGHT][OUT_WIDTH];

  initial begin
    clock = 0;
    forever #5 clock = ~clock;
  end

  initial begin
    reset_n = 0;
    #20 reset_n = 1;
    $display("TB: Reset deasserted");
  end

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

  task automatic load_image_and_expected_output();
    input_image = '{'{8, 1, 5, 3}, '{6, 7, 2, 4}, '{9, 0, 3, 2}, '{1, 5, 6, 8}};
    expected_output_image = '{'{8, 5}, '{9, 8}};
    $display("TB: Input image and expected output loaded.");
  endtask

  task automatic drive_input();
    features_in.valid = 1;
    for (int row = 0; row < IMAGE_HEIGHT; row++) begin
      for (int col = 0; col < IMAGE_WIDTH; col++) begin
        features_in.features[0] = input_image[row][col];
        @(posedge clock);
        while (!features_in.ready) begin
          $display("TB: Waiting for DUT to be ready for input");
          @(posedge clock);
        end
        $display("TB: Sent input image[%0d][%0d] = %0d", row, col, input_image[row][col]);
      end
    end
    features_in.valid = 0;
  endtask

  task automatic capture_output();
    features_out.ready = 1;
    for (int row = 0; row < OUT_HEIGHT; row++) begin
      for (int col = 0; col < OUT_WIDTH; col++) begin
        while (!features_out.valid) begin
          $display("TB: Waiting for DUT to provide valid output");
          @(posedge clock);
        end
        output_image[row][col] = features_out.features[0];
        $display("TB: Captured output image_out = [%0d][%0d]",
                 row, col, features_out.features[0]);
        @(posedge clock);
      end
    end
    features_out.ready = 0;
  endtask

  task automatic compare_output();
    int mismatches = 0;
    for (int row = 0; row < OUT_HEIGHT; row++) begin
      for (int col = 0; col < OUT_WIDTH; col++) begin
        if (output_image[row][col] !== expected_output_image[row][col]) begin
          $display("TB: Mismatch at [%0d][%0d]: Expected %0d, Got %0d",
                   row, col, expected_output_image[row][col], output_image[row][col]);
          mismatches++;
        end
      end
    end

    if (mismatches == 0)
      $display("TB: Test Passed!");
    else
      $display("TB: Test Failed with %0d mismatches.", mismatches);
  endtask

  task automatic display_images();
    $display("TB: Input Image:");
    for (int row = 0; row < IMAGE_HEIGHT; row++) begin
      for (int col = 0; col < IMAGE_WIDTH; col++) begin
        $write("%3d ", input_image[row][col]);
      end
      $write("\n");
    end

    $display("TB: Expected Output:");
    for (int row = 0; row < OUT_HEIGHT; row++) begin
      for (int col = 0; col < OUT_WIDTH; col++) begin
        $write("%3d ", expected_output_image[row][col]);
      end
      $write("\n");
    end

    $display("TB: DUT Output:");
    for (int row = 0; row < OUT_HEIGHT; row++) begin
      for (int col = 0; col < OUT_WIDTH; col++) begin
        $write("%3d ", output_image[row][col]);
      end
      $write("\n");
    end
  endtask

  initial begin
    load_image_and_expected_output();
    @(posedge reset_n);

    drive_input();
    capture_output();
    compare_output();
    display_images();

    $finish;
  end

endmodule

