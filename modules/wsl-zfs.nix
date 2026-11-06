# NixOS-WSL module: load the OpenZFS kernel module built by this flake
# (against the Microsoft WSL2 kernel it also ships) and provide matching
# userspace tools. Requires the flake's bzImage to be selected via
# .wslconfig, see README.
{ self }:
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.wsl-zfs;
  constants = import ../constants.nix;

  zfs-kmod = self.packages.${pkgs.system}."zfs-kmod";
  zfs-user = self.packages.${pkgs.system}."zfs-user";
in
{
  options.wsl-zfs = {
    enable = lib.mkEnableOption "OpenZFS via this flake's WSL2 kernel + kernel module";

    autoImportPools = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Run `zpool import -a -N` after loading the module.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      zfs-user
      pkgs.kmod
    ];

    systemd.services.wsl-zfs = {
      description = "Load OpenZFS kernel modules (custom WSL2 kernel)";
      wantedBy = [ "multi-user.target" ];
      after = [ "local-fs.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script =
        ''
          set -eu
          running="$(${pkgs.coreutils}/bin/uname -r)"
          expected="${constants.modDirVersion}"
          if [ "$running" != "$expected" ]; then
            echo "ERROR: running kernel '$running' does not match the kernel this ZFS module was built for ('$expected')." >&2
            echo "Copy this flake's bzImage to Windows and select it in .wslconfig, then run 'wsl --shutdown'. See the README." >&2
            exit 1
          fi
          if ! ${pkgs.coreutils}/bin/cat /proc/modules | ${pkgs.gnugrep}/bin/grep -q '^zfs '; then
            spl="$(${pkgs.findutils}/bin/find ${zfs-kmod}/lib/modules -name 'spl.ko*' | ${pkgs.coreutils}/bin/head -n1 || true)"
            if [ -n "$spl" ]; then
              ${pkgs.kmod}/bin/insmod "$spl"
            fi
            zfsmod="$(${pkgs.findutils}/bin/find ${zfs-kmod}/lib/modules -name 'zfs.ko*' | ${pkgs.coreutils}/bin/head -n1)"
            ${pkgs.kmod}/bin/insmod "$zfsmod"
          fi
        ''
        + lib.optionalString cfg.autoImportPools ''
          ${zfs-user}/bin/zpool import -a -N || true
        '';
    };
  };
}
