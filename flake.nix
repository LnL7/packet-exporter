{
  description = "A flake for packet-exporter";

  outputs = { self, nixpkgs }:
    let
      cratesFun = pkgs: import ./Cargo.nix {
        inherit pkgs;
        defaultCrateOverrides = pkgs.defaultCrateOverrides // {
          packet-exporter = attrs: {
            buildInputs = [ pkgs.curl ]
            ++ (with pkgs.darwin.apple_sdk.frameworks;
            nixpkgs.lib.optional pkgs.stdenv.isDarwin Security);
          };
        };
      };
    in
    {

      defaultPackage.x86_64-darwin = (cratesFun nixpkgs.legacyPackages.x86_64-darwin).rootCrate.build;
      defaultPackage.x86_64-linux = (cratesFun nixpkgs.legacyPackages.x86_64-linux).rootCrate.build;

      nixosModules.packet-exporter =
        { pkgs, ... }:
        {
          systemd.services."prometheus-packet-exporter".wantedBy = [ "multi-user.target" ];
          systemd.services."prometheus-packet-exporter".serviceConfig.ExecStart = "${self.defaultPackage}/bin/packet-exporter";
          systemd.services."prometheus-packet-exporter".serviceConfig.DynamicUser = "yes";
        };

    };
}
