# nixos-wsl-zfs

Microsoft WSL2 Linux **kernel with OpenZFS support** for [NixOS-WSL](https://github.com/nix-community/NixOS-WSL) (and any WSL2 distro willing to use Nix-built artifacts).

## Why

- The stock WSL2 kernel shipped by Windows (`*-microsoft-standard-WSL2`) has **no ZFS**.
- NixOS-WSL does not manage its own kernel — it boots whatever Windows provides via `%USERPROFILE%\.wslconfig`.
- Existing alternatives (e.g. [omasakun/wsl-zfs-module](https://github.com/omasakun/wsl-zfs-module)) ship prebuilt modules that must exactly match the Windows-provided kernel revision, which changes silently with Windows updates.

This flake solves it the reproducible way:

1. Builds the **Microsoft WSL2 kernel** from [microsoft/WSL2-Linux-Kernel](https://github.com/microsoft/WSL2-Linux-Kernel) (`linux-msft-wsl-6.18.y`, currently `6.18.58.1`) with Microsoft's own config **verbatim** — behavior matches the stock kernel, you just pin the version yourself.
2. Builds the **OpenZFS kernel module** from the same nixpkgs revision against that exact kernel.
3. Ships a NixOS module that loads `zfs.ko` at boot with matching `zfs`/`zpool` userspace, and **fails loudly** if the running kernel is not the one the module was built for.

## Build

```console
$ nix build .#kernel    # bzImage in ./result/bzImage
$ nix build .#zfs-kmod  # spl.ko / zfs.ko (used by the NixOS module below)
```

## Install (Windows side)

1. Copy the kernel image somewhere Windows-stable, e.g.:

```powershell
mkdir $env:USERPROFILE\.wsl-kernels
wsl -d NixOS -- cat ~/nixos-wsl-zfs/result/bzImage > $env:USERPROFILE\.wsl-kernels\bzImage-wsl-zfs
```

2. Point `.wslconfig` at it (`%USERPROFILE%\.wslconfig`):

```ini
[wsl2]
kernel=C:\\Users\\<you>\\.wsl-kernels\\bzImage-wsl-zfs
```

3. Restart WSL:

```powershell
wsl --shutdown
```

## Install (NixOS-WSL side)

Add this flake as an input to your NixOS flake:

```nix
# flake.nix
inputs.wsl-zfs.url = "github:m1tm4n404/nixos-wsl-zfs";
```

```nix
# your nixos-wsl host
inputs@{ ... }: {
  imports = [ inputs.wsl-zfs.nixosModules.wsl-zfs ];
  wsl-zfs.enable = true;
  # optional: import all visible pools without mounting:
  # wsl-zfs.autoImportPools = true;
}
```

Then `sudo nixos-rebuild switch --flake .#yourhost` and verify:

```console
$ uname -r
6.18.58.1-microsoft-standard-WSL2
$ zfs version
zfs-2.4.4-1
zfs-kmod-2.4.4-1
```

## Usage example: receive a dataset from a remote ZFS host

Give WSL a disk to work with (either a VHDX or a bare physical disk):

```powershell
wsl --mount --vhd D:\pools\zfs.vhdx --bare        # virtual disk
# or, for a whole physical disk (admin):
wsl --mount \\.\PHYSICALDRIVE3 --bare
```

Then inside WSL:

```console
$ sudo zpool create tank /dev/sdX          # one-time
$ ssh remote-host 'zfs send -R pool/home@snap' | sudo zfs receive tank/home
```

## Updating the kernel

1. Pick the release commit from [`linux-msft-wsl-6.18.y`](https://github.com/microsoft/WSL2-Linux-Kernel/commits/linux-msft-wsl-6.18.y).
2. Update `constants.nix` (`msRev`, `msVersion`, `modDirVersion`) and fetch the new hash:

```console
$ nix store prefetch-file --hash-type sha256 \
    https://github.com/microsoft/WSL2-Linux-Kernel/archive/<rev>.tar.gz
```

3. Copy the matching `arch/x86/configs/config-wsl` to `kernel/config-wsl-<version>`, update the path in `flake.nix`.
4. Rebuild, reinstall `bzImage` (Windows side), `wsl --shutdown`.

## Caveats

- You pin the kernel: Windows no longer auto-updates it (that is the point, but security updates are now your job — bump the rev regularly).
- `wsl --mount --bare` requires Windows 11 and admin rights.
- Built kernel is GPL-2.0 (as upstream); the Nix expressions here are MIT.
