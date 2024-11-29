package mnist_pkg;

  parameter feature_size          = 16;
  parameter weight_size           = 16;
  parameter feature_integer_bits  =  8;
  parameter weight_integer_bits   =  8;
  parameter feature_frac_bits     = feature_size - feature_integer_bits;
  parameter weight_frac_bits      = weight_size  - weight_integer_bits;

  typedef logic signed [feature_size-1:0]              feature_type;
  typedef logic signed [weight_size-1:0]               weight_type;
  typedef logic signed [feature_size+weight_size-1:0]  sum_type;

  function real feature_to_real(input feature_type n);
    real r;
    r = real'(n)/real'(1<<feature_frac_bits);
    return r;
  endfunction : feature_to_real

  function real weight_to_real(input weight_type n);
    return real'(n)/real'(1<<weight_frac_bits);
  endfunction : weight_to_real

  function real sum_to_real(input sum_type n);
    return real'(n)/real'(1<<feature_frac_bits);
  endfunction : sum_to_real

  function feature_type real_to_feature(input real r);
    return feature_type'(int'(r * (1<<feature_frac_bits)));
  endfunction : real_to_feature

  function feature_type int_to_feature(input int i);
    return feature_type'(i * (1<<feature_frac_bits));
  endfunction : int_to_feature

  function weight_type real_to_weight(input real r);
    return weight_type'(int'(r * (1<<weight_frac_bits)));
  endfunction : real_to_weight

  function weight_type int_to_weight(input int i);
    return feature_type'(i * (1<<weight_frac_bits));
  endfunction : int_to_weight

endpackage : mnist_pkg
