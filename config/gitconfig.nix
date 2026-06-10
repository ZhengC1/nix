{ ... }:

{
  programs.git = {
    enable = true;

    userName = "Chun Zheng";
    userEmail = "zhengc42@gmail.com";

    aliases = {
      st = "status";
      ci = "commit";
      sw = "switch";
      br = "branch";
      co = "checkout";
      df = "diff";
      lg = "log -p";
      ls = "ls-files";
      p = "push";
      lol = "log --graph --pretty=format:'%C(yellow)%h%Creset %an: %s - %Creset %C(yellow)%d%Creset %Cblue(%cr)%Creset' --abbrev-commit --date=relative";
      lola = "log --graph --pretty=format:'%C(yellow)%h%Creset %an: %s - %Creset %C(yellow)%d%Creset %Cblue(%cr)%Creset' --abbrev-commit --date=relative --all";
    };

    extraConfig = {
      core.editor = "vim";
      color = {
        ui = "auto";
        branch = {
          current = "yellow reverse";
          local = "yellow";
          remote = "green";
        };
        diff = {
          meta = "yellow bold";
          frag = "magenta bold";
          old = "red bold";
          new = "green bold";
        };
        status = {
          added = "green";
          changed = "yellow";
          untracked = "red";
        };
      };
    };
  };
}
