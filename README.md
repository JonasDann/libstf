# Standard Library for Coyote vFPGAs (libstf)

This library is a collection of common modules used to develop vFPGAs for Coyote. For now this is
very bare bones. A bunch of modules may be broken. For now, we have a couple of code style rules:

1. Camel case for class names and snake case for file names and everything else in the code
2. _i postfix for interfaces
3. _t postfix for types
4. n_ prefix for next signals in state logic

## Next TODOs
1. Refactor and rewrite unit tests for OutputWriter