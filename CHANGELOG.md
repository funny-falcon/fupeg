## [0.3.0] - 2023-08-28

- Grammar.use_gram - to simplier grammar inclusion
- Grammar.proxy - to proxy rules to included grammar
- `_(pat)` doesn't return matched text, use `txt(pat)` instead
- "\`" is specialized for tokens
-- token is either ident (which is specified with `ident_only` method), or symbols,
-- `token_sp?` is skipped after token
- fixes for position calculation

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
