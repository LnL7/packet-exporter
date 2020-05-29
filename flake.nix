{
  description = "A flake for packet-exporter";

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);
    in
    {

      defaultPackage = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; }; in
        (import ./Cargo.nix {
          inherit pkgs;
          defaultCrateOverrides = pkgs.defaultCrateOverrides // {
            packet-exporter = attrs: {
              buildInputs = [ pkgs.curl ]
              ++ (with pkgs.darwin.apple_sdk.frameworks;
              nixpkgs.lib.optional pkgs.stdenv.isDarwin Security);
            };
          };
        })
        .rootCrate.build);

      nixosModules.packet-exporter =
        { pkgs, ... }:
        {
          systemd.services."prometheus-packet-exporter".wantedBy = [ "multi-user.target" ];
          systemd.services."prometheus-packet-exporter".serviceConfig.ExecStart = "${self.defaultPackage}/bin/packet-exporter";
          systemd.services."prometheus-packet-exporter".serviceConfig.DynamicUser = "yes";
        };

    };
}
