{
  description = "A flake providing a NixOS module for the Espial bookmarking server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: {
    nixosModules.espial = import ./espial-module.nix;
    nixosModules.default = self.nixosModules.espial;
    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.alejandra;
  };
}
