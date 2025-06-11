# Kiwi Language

A toy language I'm building in Zig.

You can find examples in the [docs directory](./docs/examples), and formal grammar [here](./docs/grammar.pdf).

Note: variables are always immutable.

More features are being actively worked on.

## Compilation:

```bash
zig build
```

## Running:

```bash
zig build run -- test.kw program
zig cc program.o -o program
./program
```

There must be a `test.kw` file in the root of the project with example Kiwi code.

Note: the above steps can be automated by running `./run.sh`.

## Implementation Status

### ✅ Working

- [x] Basic variable declarations (with type annotations)
- [x] Arithmetic expressions (`+`, `-`, `*`, `/`)
- [x] Return statements
- [x] Variable references
- [x] Function declarations and calls
- [x] Function parameters and return types
- [x] Function calls

### 🔄 In Development

- [ ] Conditional statements
- [ ] Comparison operators
- [ ] Logical operators
- [ ] Booleans
- [ ] Basic error messages

### 📋 Planned

- [ ] Type checking and validation
- [ ] Basic IO
- [ ] First Class Functions
- [ ] Arrays/Hashmaps
- [ ] Pattern matching
- [ ] Tuples
- [ ] Import system/stdlib
- [ ] More advanced compiler error messages
- [ ] Comments
- [ ] Lambda Expressions
- [ ] Strings
- [ ] Error handling

### 🐛 Known Issues

- [ ] Main function does not check what its return type is
