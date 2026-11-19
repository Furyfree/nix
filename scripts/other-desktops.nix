# For scripts/eval.sh: each NixOS host with every compositor it can pick
# besides its own, as "host (desktop): drvPath" lines.
hosts:
let
  other =
    name: desktop:
    let
      host = hosts.${name}.extendModules {
        modules = [ ({ lib, ... }: { workstation.desktop = lib.mkForce desktop; }) ];
      };
    in
    "${name} (${desktop}): ${host.config.system.build.toplevel.drvPath}\n";
  evaluate =
    name:
    let
      inherit (hosts.${name}) config options;
    in
    map (other name) (
      builtins.filter (
        desktop: desktop != config.workstation.desktop
      ) options.workstation.desktop.type.functor.payload.values
    );
in
builtins.concatStringsSep "" (
  builtins.concatMap evaluate (
    builtins.filter (name: hosts.${name}.options ? workstation) (builtins.attrNames hosts)
  )
)
