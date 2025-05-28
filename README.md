# kiwi

A toy language I'm building in Zig. Example usage:

`return 1;`

Or, expressions:

`return 1+2+3;`

More features are planned to be added.

## Compilation:

```bash
zig build
zig build run -- test.txt program
gcc program.o -o program
./program
```

There must be a `test.txt` file in the root of the project with example Kiwi code.
