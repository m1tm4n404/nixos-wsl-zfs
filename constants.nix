{
  # Microsoft WSL2 kernel source, pinned by commit.
  # Branch: linux-msft-wsl-6.18.y, release commit "WSL Kernel 6.18.58.1".
  msRev = "a989171929bed4ea681be8d77333845ce1c1732a";
  msVersion = "6.18.58.1";
  # CONFIG_LOCALVERSION in Microsoft's arch/x86/configs/config-wsl.
  localversion = "-microsoft-standard-WSL2";
  # Full `uname -r` of the built kernel (version + localversion).
  modDirVersion = "6.18.58.1-microsoft-standard-WSL2";
  # sha256 of https://github.com/microsoft/WSL2-Linux-Kernel/archive/${msRev}.tar.gz
  # (nix store prefetch-file --hash-type sha256 <url>)
  srcHash = "sha256-6zyNYVfeSshDs1959gQ8uCWDMlpjW9GUKK895bBkGtc=";

  # ---- "stock kernel" mode ------------------------------------------------
  # Build only the ZFS module against a vanilla kernel.org source release whose
  # version + CONFIG_LOCALVERSION match the Windows-provided WSL2 kernel
  # (`uname -r`), so the module loads into the STOCK kernel without replacing
  # it. Must be bumped whenever Windows updates the WSL2 kernel.
  stockVersion = "6.18.57";
  stockModDirVersion = "6.18.57-microsoft-standard-WSL2";
  # sha256 of https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${stockVersion}.tar.xz
  stockSrcHash = "sha256-W9ms3ILsXvw3kK6EDlqqQN/efv/yYc9t3pAtxXCs+Yw=";
}
