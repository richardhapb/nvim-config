; inherits: javascript
; extends
(variable_declaration
(variable_declarator
  name: (_) @assignment.lhs
	value: (_) @assignment.inner @assignment.rhs)) @assignment.outer
