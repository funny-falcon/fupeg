## [0.2.0] - 2023-08-15

- Split Parser and Grammar
- Use `_` for both literals and sequence:
  `_("x")` , `_(/x/)`, `_{ _("x") }`
- Use backtick "\`" for string literals
  `x`
- `cont?` used with block to detect uncutted alternative
```ruby
  cut {
    # condition
    _ { `if` && cut! && ... } ||
    # loop
    cont? { `while` && cut! && ...} ||
    # assignment
    cont? { (i = ident) && sp? && `=` && cut! && ... } ||
    # function call
    cont? { (i = ident) && sp? && `(` && cut! && ... } ||
    ...
  }
```

## [0.1.0] - 2023-08-14

- Initial release
- Simplest rule definition in Ruby code without magic
