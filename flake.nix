{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {
    nixpkgs,
    ...
  }: let
    inherit (nixpkgs) lib;
    eachSystem = lib.genAttrs [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  in {
    packages = eachSystem (system: let
      pkgs = import nixpkgs {inherit system;};
    in rec {
      infra-keyval = pkgs.callPackage ./nix/package.nix {};
      default = infra-keyval;
    });

    devShell = eachSystem (system: let
      pkgs = import nixpkgs {inherit system;};
    in
      pkgs.mkShell {
        buildInputs = with pkgs; [
          cargo
          rustc
          rustfmt
          rust-analyzer
          clippy
        ];
      });

    nixosModules = rec {
      infra-keyval = import ./nix/module.nix;
      default = infra-keyval;
    };
  };
}
