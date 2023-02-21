# espial-nix [WIP]

`espial-nix` is a Nix flake providing a NixOS module for the [Espial bookmarking server][espial].

## Usage

In your NixOS system configuration, add this flake to your inputs and enable the provided Espial module. As of `2023-02-21`, `espial` on `nixpkgs/master` is broken, so adding the nixpkgs' `haskell-updates` branch to your flake inputs as well may also be desirable:

```nix
{
  inputs = {
    espial-nix.url = "github:ozkutuk/espial-nix";
    haskell-updates.url = "github:NixOS/nixpkgs/haskell-updates";
  };

  outputs = { self, nixpkgs, espial-nix, haskell-updates }:
    let
      system = "x86_64-linux";

      haskellUpdates = import haskell-updates {
        inherit system;
      };
    in
      nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
        modules = [
          espial-nix.nixosModule
          {
            services.espial = {
              enable = true;
              package = haskellUpdates.haskellPackages.espial;
              database = {
                user = "testuser";
                passwordFile = "/etc/nixos/secrets/passwordFile-testuser";
              };
            };
          }
        ];
      }
}
```

Of course, you have to create the password file yourself beforehand. After enabling the module, you can then reverse proxy to the service on port `3000`. For simpler use cases, `services.espial.openFirewall` is also provided.


[espial]: https://github.com/jonschoning/espial
