
(expression_statement
  (assignment
    right: (dictionary) @dict))

(call
  arguments: (argument_list
               (keyword_argument
                 value: (dictionary) @dict)))

(block
  (return_statement
    (dictionary) @dict))

(call
  arguments: (argument_list
               (dictionary) @dict))

(dictionary
  (pair
    value: (dictionary) @nested_dict))

(dictionary
  (pair
    value: (list) @nested_list))

(function_definition) @function
(class_definition) @class

