

import mnist_pkg::feature_type;

module max_pool #(
    parameter int ROW_STRIDE    = 2,  // Stride for rows
    parameter int COL_STRIDE    = 2,  // Stride for columns
    parameter int IMAGE_HEIGHT  = 4,  // Input image height
    parameter int IMAGE_WIDTH   = 4   // Input image width
)(
    input  logic        clock,         // Clock signal
    input  logic        reset_n,       // Active-low reset
    feature_if          features_in,   // Input feature interface
    feature_if          features_out   // Output feature interface
);

    // Internal arrays for image storage
    feature_type image[IMAGE_HEIGHT][IMAGE_WIDTH];
    feature_type image_out[IMAGE_HEIGHT / ROW_STRIDE][IMAGE_WIDTH / COL_STRIDE];

    // State variables
    logic [$clog2(IMAGE_HEIGHT):0] in_row, in_col;       // Input address counters
    logic [$clog2(IMAGE_HEIGHT):0] out_row, out_col;     // Output address counters
    logic [$clog2(IMAGE_HEIGHT):0] addr_row, addr_col;   // Address of the top-left corner of the pooling region
    logic send;                                          // Signal to start sending output

    // Assignments for computing max values in a 2x2 pooling region
    feature_type upper_row_max, lower_row_max, max_value;

    assign upper_row_max = (image[addr_row][addr_col] > image[addr_row][addr_col + 1])
                           ? image[addr_row][addr_col]
                           : image[addr_row][addr_col + 1];

    assign lower_row_max = (image[addr_row + 1][addr_col] > image[addr_row + 1][addr_col + 1])
                           ? image[addr_row + 1][addr_col]
                           : image[addr_row + 1][addr_col + 1];

    assign max_value = (upper_row_max > lower_row_max) 
                       ? upper_row_max 
                       : lower_row_max;

    // -------------------------------------------------------------------------
    // Input State Machine: Load Input Image
    // -------------------------------------------------------------------------
    always_ff @(posedge clock or negedge reset_n) begin
        if (!reset_n) begin
            in_row <= 0;
            in_col <= 0;
        end else if (features_in.valid && features_in.ready) begin
            image[in_row][in_col] <= features_in.features[0];
            $display("DUT: Loaded input image[%0d][%0d] = %0d", in_row, in_col, features_in.features[0]);
            if (in_col + 1 < IMAGE_WIDTH) begin
                in_col <= in_col + 1;
            end else begin
                in_col <= 0;
                in_row <= in_row + 1;
            end
        end
    end

    assign features_in.ready = (in_row < IMAGE_HEIGHT);

    // -------------------------------------------------------------------------
    // Max Pooling Logic: Compute Max and Store in Output Array
    // -------------------------------------------------------------------------
    always_ff @(posedge clock or negedge reset_n) begin
        if (!reset_n) begin
            addr_row <= 0;
            addr_col <= 0;
            send <= 0;  // Ensure sending only starts after computation
        end else if (in_row == IMAGE_HEIGHT) begin
            if (addr_col + COL_STRIDE < IMAGE_WIDTH) begin
                addr_col <= addr_col + COL_STRIDE;
            end else begin
                addr_col <= 0;
                if (addr_row + ROW_STRIDE < IMAGE_HEIGHT) begin
                    addr_row <= addr_row + ROW_STRIDE;
                end else begin
                    addr_row <= 0;
                    send <= 1;  // Indicate that all regions are processed
                end
            end
            // Store the computed max value in the output array
            image_out[addr_row / ROW_STRIDE][addr_col / COL_STRIDE] <= max_value;
            $display("DUT: Computed max for region [%0d:%0d][%0d:%0d] = %0d",
                     addr_row, addr_row + ROW_STRIDE - 1, addr_col, addr_col + COL_STRIDE - 1, max_value);
        end
    end

    // -------------------------------------------------------------------------
    // Output State Machine: Send Max-Pooled Results
    // -------------------------------------------------------------------------
    always_ff @(posedge clock or negedge reset_n) begin
        if (!reset_n) begin
            out_row <= 0;
            out_col <= 0;
        end else if (send) begin  // Only start sending after computation
            if (features_out.ready && features_out.valid) begin
                if (out_col + 1 < (IMAGE_WIDTH / COL_STRIDE)) begin
                    out_col <= out_col + 1;  // Move to the next column
                end else begin
                    out_col <= 0;  // Reset column
                    if (out_row + 1 < (IMAGE_HEIGHT / ROW_STRIDE)) begin
                        out_row <= out_row + 1;  // Move to the next row
                    end else begin
                        out_row <= 0;  // Reset after transmitting all outputs
                        $display("DUT: Finished sending all outputs");
                    end
                end
                $display("DUT: Sending output image_out = [%0d][%0d]",
                         out_row, out_col, image_out[out_row][out_col]);
            end
        end
    end

    assign features_out.valid = (send && out_row < (IMAGE_HEIGHT / ROW_STRIDE));
    assign features_out.features[0] = image_out[out_row][out_col];

<<<<<<< HEAD
   // -------------------------------------------------------------------------
   // behavioral algorithm for max pool -- todo: re-write as synthesizable hardware
   // -------------------------------------------------------------------------

   initial begin
     send = 0;
     receive = 0;
     @(posedge reset_n);
     @(posedge clock);

     forever begin

       // read in features
       receive = 1;
       @(posedge clock);
       receive = 0;
       while (rx_state != RX_DONE) @(posedge clock);
       @(posedge clock);

       // process max pool
       for (int row=0; row<IMAGE_HEIGHT; row+=ROW_STRIDE) begin
         for (int col=0; col<IMAGE_WIDTH; col+=COL_STRIDE) begin
           max = image[row][col];
           for (int r=0; r<ROW_STRIDE; r++) begin
             for (int c=0; c<COL_STRIDE; c++) begin
               if (max < image[row+r][col+c]) max = image[row+r][col+c];
             end
           end
           image_out[row/ROW_STRIDE][col/COL_STRIDE] = max;
         end
       end

       // write out results
       send = 1;
       @(posedge clock);
       send = 0;
       while (tx_state != TX_DONE) @(posedge clock);
       @(posedge clock);
     end   
  end


endmodule : max_pool
=======
endmodule

>>>>>>> 0ecb71034aa8bde77897bec57fb03a18d92f8ced
