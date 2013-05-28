ex1 = [ 1, 2, 3, 4, 5 ]
ex2 = "some string"
ex3 = { :foo => 42, ex1 => ex2 }
ex4 = [ ex1, ex2, ex3, { ex3 => ex3, ex2 => ex2.to_sym, nil => false, true => [ {} ] } ]
ex5 = [ nil, true, false, 2**100, 3.14 ]
exs = [ ex1, ex2, ex3, ex4, ex5 ]
exs << exs
EXAMPLES = exs
