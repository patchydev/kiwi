{
  pkgs ? import <nixpkgs> { },
}:

pkgs.mkShell {
  buildInputs = with pkgs; [
    llvm_18
    llvm_18.dev
    zig
    pkg-config
    cmake
  ];

  shellHook = ''
    export LLVM_CONFIG=${pkgs.llvm_18.dev}/bin/llvm-config
    export LLVM_SYS_180_PREFIX=${pkgs.llvm_18.dev}
    export PKG_CONFIG_PATH="${pkgs.llvm_18.dev}/lib/pkgconfig:$PKG_CONFIG_PATH"
    export SHELL=${pkgs.zsh}/bin/zsh
    zsh
  '';
}
