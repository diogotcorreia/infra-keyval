{
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage rec {
  pname = "infra-keyval";
  version = "0.1.1";

  src = ../.;
  cargoLock.lockFile = ../Cargo.lock;

  meta = {
    changelog = "https://github.com/diogotcorreia/infra-keyval/releases/tag/${version}";
    description = "Key-value store for infra-related config";
    homepage = "https://github.com/diogotcorreia/infra-keyval";
    license = lib.licenses.gpl3;
    mainProgram = "infra-keyval";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
