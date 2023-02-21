{
  description = "A flake providing a NixOS module for the Espial bookmarking server";

  outputs = { self }: {
    nixosModule = ./espial-module.nix;
  };
}
