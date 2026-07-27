{ pkgs, ... }:

{
  # macOS-specific configuration
  home.packages = with pkgs; [
    # Required for Python to build lzma support
    xz
  ];
}
