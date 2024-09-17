{
  pkgs,
  ...
}:

{
  imports = [
    ./impermanence.nix
  ];

  environment.systemPackages = with pkgs; [
    duf
    tldr
    tree
  ];
}
