
  (expression_statement
    (assignment
      left: (identifier)
    right: (dictionary
             (pair) @dict_pair) @dict))

(call
function: (identifier)
arguments: (argument_list
             (keyword_argument
             value: (dictionary
                      (pair) @dict_pair) @dict
            )
        )
    ) @call

(call
function: (identifier)
arguments: (argument_list
             (dictionary
                      (pair) @dict_pair) @dict
        )
    ) @call
