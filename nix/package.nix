{ rustPlatform }:
rustPlatform.buildRustPackage {
  pname = "infra-keyval";
  version = "0.1.0";

  src = ../.;
  cargoLock.lockFile = ../Cargo.lock;
}

