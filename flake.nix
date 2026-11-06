{
  description = "Microsoft WSL2 Linux kernel with OpenZFS support for NixOS-WSL";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      constants = import ./constants.nix;

      wslKernel = pkgs.linuxKernel.manualConfig {
        inherit (pkgs) stdenv lib;
        inherit (constants) msVersion modDirVersion;
        src = pkgs.fetchurl {
          url = "https://github.com/microsoft/WSL2-Linux-Kernel/archive/${constants.msRev}.tar.gz";
          hash = constants.srcHash;
        };
        configfile = ./kernel/config-wsl-6.18.58.1;
        allowImportFromDerivation = true;
      };

      wslKernelPackages = pkgs.linuxKernel.packagesFor wslKernel;

      # Vanilla kernel.org source + Microsoft's WSL config, versioned to match
      # the STOCK Windows-provided WSL2 kernel, so the resulting ZFS module
      # loads without replacing the kernel. See constants.nix.
      stockWslKernel = pkgs.linuxKernel.manualConfig {
        inherit (pkgs) stdenv lib;
        version = constants.stockVersion;
        modDirVersion = constants.stockModDirVersion;
        src = pkgs.fetchurl {
          url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${constants.stockVersion}.tar.xz";
          hash = constants.stockSrcHash;
        };
        configfile = ./kernel/config-wsl-6.18.58.1;
        allowImportFromDerivation = true;
      };

      stockWslKernelPackages = pkgs.linuxKernel.packagesFor stockWslKernel;
    in
    {
      packages.${system} = {
        # The kernel itself; bzImage lands in $out/bzImage. Point .wslconfig at it.
        kernel = wslKernel;

        # OpenZFS kernel module (spl.ko/zfs.ko) built against the kernel above.
        zfs-kmod = wslKernelPackages.zfs;

        # OpenZFS kernel module for the STOCK Windows-provided WSL2 kernel.
        # No kernel replacement needed; rebuild when Windows bumps `uname -r`.
        zfs-kmod-stock = stockWslKernelPackages.zfs;

        # OpenZFS userspace from the same nixpkgs revision as the module,
        # so `zfs`/`zpool` versions always match the loaded kmod.
        zfs-user = pkgs.zfs;

        default = wslKernel;
      };

      nixosModules.wsl-zfs = import ./modules/wsl-zfs.nix { inherit self; };
      nixosModules.default = self.nixosModules.wsl-zfs;

      overlays.default = final: _prev: {
        wsl-zfs-kernel = self.packages.${final.system}.kernel;
        wsl-zfs-kmod = self.packages.${final.system}.zfs-kmod;
      };
    };
}
