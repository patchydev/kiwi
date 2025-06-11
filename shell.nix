{
  pkgs ? import <nixpkgs> { },
}:

pkgs.mkShell {
  buildInputs = with pkgs; [
    llvm_18.dev
    zig
  ];

  shellHook = ''
    SHELL=${pkgs.zsh}/bin/zsh
    zsh
  '';
}
