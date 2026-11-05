# Local models through llama.cpp's router: it loads one model when a request
# names it, fits the model and context to free GPU memory, offloading MoE
# experts to system RAM when needed, and unloads it after ten idle minutes so
# games and dictation get the GPU back. Models download from Hugging Face on
# first load into /var/cache/llama-cpp, outside Git and the Nix store. Hosts
# choose the GPU build; Vulkan suits AMD and Intel graphics.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.services.llama-cpp.settings) host port;
  url = "http://${host}:${toString port}";
  # Enough room for coding agents; fit offloads weights rather than shrink it.
  context = 65536;

  # The model IDs that clients request, each with its llama.cpp settings and
  # the name and longest answer OpenCode uses. Unsloth Dynamic 4-bit quants
  # keep the sensitive layers at higher precision, with the fixed chat
  # templates.
  models = {
    # MoE, 35B with 3B active, with image input: the strongest model with ~3B
    # active parameters for coding and agents. Qwen's settings for coding;
    # agents keep earlier reasoning, which fixes truncated tool calls and lets
    # the prompt cache be reused.
    "qwen3.6-35b-a3b" = {
      name = "Qwen3.6 35B-A3B";
      output = 32768;
      settings = {
        hf-repo = "unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q4_K_XL";
        temp = 0.6;
        top-p = 0.95;
        top-k = 20;
        min-p = 0;
        chat-template-kwargs = ''{"preserve_thinking":true}'';
      };
    };
    # Small and fast, with image input; fits the desktop GPU whole.
    "gemma-4-e4b" = {
      name = "Gemma 4 E4B";
      output = 16384;
      settings = {
        hf-repo = "unsloth/gemma-4-E4B-it-GGUF:UD-Q4_K_XL";
        temp = 1.0;
        top-p = 0.95;
        top-k = 64;
      };
    };
  };

  # OpenCode's entry for this server, written whole on each switch so a
  # removed model leaves OpenCode too.
  opencodeProvider = pkgs.writeText "opencode-llama-cpp.json" (
    builtins.toJSON {
      npm = "@ai-sdk/openai-compatible";
      name = "llama.cpp";
      options.baseURL = "${url}/v1";
      models = lib.mapAttrs (_: model: {
        inherit (model) name;
        limit = {
          inherit context;
          inherit (model) output;
        };
      }) models;
    }
  );

  # Chat in the terminal through the server, which loads the model you pick
  # with its settings above, rather than a second copy in llama-cli.
  llamaChat = pkgs.writeShellApplication {
    name = "llama-chat";
    text = ''
      exec ${lib.getExe' config.services.llama-cpp.package "llama-cli"} --server-base ${url} "$@"
    '';
  };
in
{
  services.llama-cpp = {
    enable = true;
    package = lib.mkDefault pkgs.llama-cpp-vulkan;
    settings = {
      # Section names are the model IDs that clients request.
      models-preset = pkgs.writeText "llama-models.ini" (
        lib.generators.toINIWithGlobalSection { } {
          globalSection.version = 1;
          sections = {
            "*" = {
              ctx-size = context;
              # Hide the cache entries of the models below from /models.
              dedup-cache-models = true;
            };
          }
          // lib.mapAttrs (_: model: model.settings) models;
        }
      );
      # One model at a time keeps memory for the desktop session.
      models-max = 1;
      sleep-idle-seconds = 600;
      # Only local pages may read responses; the default lets any website.
      cors-origins = "localhost";
    };
  };

  # The same build for llama-cli and the other tools.
  environment.systemPackages = [
    config.services.llama-cpp.package
    llamaChat
  ];

  # The service has no home, so GPU drivers keep compiled shaders here instead
  # of rebuilding them on every model load.
  systemd.services.llama-cpp.environment.XDG_CACHE_HOME = "/var/cache/llama-cpp";

  # After home/common.nix merges configs/opencode into OpenCode's own file.
  home-manager.sharedModules = [
    (
      { config, lib, ... }:
      {
        home.activation.opencodeLocalModels = lib.hm.dag.entryAfter [ "toolSettings" ] ''
          file=${config.xdg.configHome}/opencode/opencode.jsonc
          if [[ -s $file ]]; then
            if updated=$(${lib.getExe pkgs.yq-go} -p json -o json \
              '.provider["llama.cpp"] = load("${opencodeProvider}")' "$file"); then
              [[ -v DRY_RUN ]] || printf '%s\n' "$updated" >"$file"
            else
              warnEcho "Skipping $file: Yq cannot read it."
            fi
          fi
        '';
      }
    )
  ];
}
