{
  description = "A flake for packet-exporter";

  outputs = { self, nixpkgs }: {

    crates.x86_64-darwin =
      let pkgs = nixpkgs.legacyPackages.x86_64-darwin; in
      import ./Cargo.nix {
        inherit pkgs;
        defaultCrateOverrides = pkgs.defaultCrateOverrides // {
          packet-exporter = attrs: {
            buildInputs = [ pkgs.curl ]
              ++ (with pkgs.darwin.apple_sdk.frameworks;
                  nixpkgs.lib.optional pkgs.stdenv.isDarwin Security);
          };
        };
      };

    crates.x86_64-linux =
      let pkgs = nixpkgs.legacyPackages.x86_64-linux; in
      import ./Cargo.nix {
        inherit pkgs;
        defaultCrateOverrides = pkgs.defaultCrateOverrides // {
          packet-exporter = attrs: {
            buildInputs = [ pkgs.curl ]
              ++ (with pkgs.darwin.apple_sdk.frameworks;
                  nixpkgs.lib.optional pkgs.stdenv.isDarwin Security);
          };
        };
      };

    defaultPackage.x86_64-darwin = self.crates.x86_64-darwin.rootCrate.build;
    defaultPackage.x86_64-linux = self.crates.x86_64-linux.rootCrate.build;

    nixosModules.packet-exporter =
      { pkgs, ... }:
      {
        systemd.services."prometheus-packet-exporter".wantedBy = [ "multi-user.target" ];
        systemd.services."prometheus-packet-exporter".serviceConfig.ExecStart = "${self.defaultPackage}/bin/packet-exporter";
        systemd.services."prometheus-packet-exporter".serviceConfig.DynamicUser = "yes";
      };

  };
}
