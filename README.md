# kiwi

A toy language I'm building in Zig. Example usage:

`return 1;`

Or expressions:

`return 1*2+3;`

Currently supported in expressions:

- Addition
- Subtraction
- Multiplication
- Division

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
