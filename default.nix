let pkgs = import <nixpkgs> {};
in
pkgs.mkShell {
  buildInputs = with pkgs; [
    texlive.combined.scheme-full
  ];
}
