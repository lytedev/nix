{ self, pkgs, ... }:
{
  imports = with self.outputs.nixosModules; [
    lutris # TODO: use the flatpak?
    steam # TODO: use the flatpak?
  ];

  environment = {
    systemPackages = with pkgs; [
      ludusavi
      # ludusavi uses rclone
      rclone
    ];
  };
}
