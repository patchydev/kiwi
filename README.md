# kiwi

A toy language I'm building in Zig. Example usage:

```
return 1;
```

Or expressions:

```
return 1*2+3;
```

Or variables:

```
let x = 1;
let y = x + 2;
return y;
```

Note: variables are always immutable.

You can find examples in the [docs directory](./docs/examples), and formal grammar [here](./docs/grammar.pdf).

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

- [x] Basic variable declarations (without type annotations)
- [x] Arithmetic expressions (`+`, `-`, `*`, `/`)
- [x] Return statements
- [x] Variable references

### 🔄 In Development

- [ ] Type annotations for variables
- [ ] Function declarations and calls
- [ ] Function parameters and return types
- [ ] Function calls

### 📋 Planned

- [ ] Type checking and validation
- [ ] Conditional statements
- [ ] Strings
- [ ] Booleans
- [ ] Error handling
