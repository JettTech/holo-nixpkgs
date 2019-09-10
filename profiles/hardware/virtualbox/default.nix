{ config, pkgs, ... }:

let
  nixpkgs = import ../../../vendor/nixpkgs.nix;
in

{
  imports = [
    "${nixpkgs}/nixos/modules/virtualisation/virtualbox-image.nix"
  ];

  system.holoportos.target = "virtualbox";

  virtualbox.vmFileName =
    "holoportos-for-${config.system.holoportos.target}.ova";

  virtualisation.virtualbox.guest.x11 = false;
}
