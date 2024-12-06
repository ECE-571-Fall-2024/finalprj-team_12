import mnist_pkg::feature_type;

module max_pool #(
    parameter int ROW_STRIDE    = 2,  // Stride for rows (NxN pooling: N is ROW_STRIDE)
    parameter int COL_STRIDE    = 2,  // Stride for columns
    parameter int IMAGE_HEIGHT  = 6,  // Input image height
    parameter int IMAGE_WIDTH   = 6   // Input image width
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

    // Max value computation for NxN pooling
    feature_type max_value;

    always_comb begin
        max_value = image[addr_row][addr_col];  // Initialize max_value with the first element in the region
        for (int i = 0; i < ROW_STRIDE; i++) begin
            for (int j = 0; j < COL_STRIDE; j++) begin
                if (image[addr_row + i][addr_col + j] > max_value) begin
                    max_value = image[addr_row + i][addr_col + j];
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // Input State Machine: Load Input Image
    // -------------------------------------------------------------------------
    always_ff @(posedge clock or negedge reset_n) begin
        if (!reset_n) begin
            in_row <= 0;
            in_col <= 0;
        end else if (features_in.valid && features_in.ready) begin
            image[in_row][in_col] <= features_in.features[0];
            //$display("DUT: Loaded input image[%0d][%0d] = %0d", in_row, in_col, features_in.features[0]);
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
            //$display("DUT: Computed max for region [%0d:%0d][%0d:%0d] = %0d",
                     //addr_row, addr_row + ROW_STRIDE - 1, addr_col, addr_col + COL_STRIDE - 1, max_value);
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
                        //$display("DUT: Finished sending all outputs");
                    end
                end
                //$display("DUT: Sending output image_out[%0d][%0d] = %0d",
                         //out_row, out_col, image_out[out_row][out_col]);
            end
        end
    end

    assign features_out.valid = (send && out_row < (IMAGE_HEIGHT / ROW_STRIDE));
    assign features_out.features[0] = image_out[out_row][out_col];

endmodule
