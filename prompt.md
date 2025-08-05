
> i'm currently working on a loss module, found in the src folder called loss.sv, with its corresponding testbench, test_loss.py. please look at fixedpoint.sv to see how to deal 
  with fixed point floating point values. refer to pe.sv, on more context on how to use fixed point. please make the module as concise and simple as possible, without stripping 
  away necessary parts for the module to work efficiently. here is what i am envisioning:\
  \
  we want a total of two loss_child modules, instantiated in a loss module. assume that each loss module gets its own column of output activations, and labels. rows represent batch
   size, columns represent features. the loss output values in a staggered fashion, hence we have two loss modules handling two columns. if we have a batch size of four, for 
  example, we would leave a few cycles for computation, and then output vlaues in the following fashion - 1, 2, 2, 2, 1. please take a look at the current unified_buffer.sv in /src
   for a better example of what i am talking about when i say "staggered". you should implement the loss calculation for mse like this - // //   • MSE loss  ( (H−Y)^2 / N )  or
  // //   • d(MSE)/dH ( 2(H−Y) / N ). assume there is a variable sized batch size (# of rows), so you should implement in the parent loss module, a feature for staggered data 
  reading from two corersponding input ports, one for each loss cihld module. \
  \
  when you are done this, please update the test_loss.py testbench to implement the following test cases - batch size 4 - 0.6831, 0.8036, 0.4905, 0.5487 output activations, labels 
  - 0, 1, 1, 0. within each child loss module, please retrieve an output activation, and h at the same time. \
  \
  you should also write another test case (use any fixed point numbers you want) for testing use of both child loss modules, as the above outlined test case only implements a 
  necessary utilization of one loss child module. there is currently some intermediate code in loss.sv for more context.


  give the decimal value of the 1/n value for 