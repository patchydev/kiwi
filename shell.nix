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
    LLVM_CONFIG=${pkgs.llvm_18.dev}/bin/llvm-config
    LLVM_SYS_180_PREFIX=${pkgs.llvm_18.dev}
    PKG_CONFIG_PATH="${pkgs.llvm_18.dev}/lib/pkgconfig:$PKG_CONFIG_PATH"
    SHELL=${pkgs.zsh}/bin/zsh
    zsh
  '';
}
