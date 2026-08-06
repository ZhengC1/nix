{ ... }:

{
  programs.git = {
    enable = true;

    # userName/userEmail/aliases/extraConfig were all folded into `settings`,
    # which mirrors git's own config schema one-to-one.
    settings = {
      user = {
        name = "Chun Zheng";
        email = "zhengc42@gmail.com";
      };

      alias = {
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
