# Local models through llama.cpp's router: it loads one model when a request
# names it, fits the model and context to free GPU memory, offloading MoE
# experts to system RAM when needed, and unloads it after ten idle minutes so
# games and dictation get the GPU back. Models download from Hugging Face on
# first load into /var/cache/llama-cpp, outside Git and the Nix store. Hosts
# choose the GPU build; Vulkan suits AMD and Intel graphics.
{ lib, pkgs, ... }:

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
              # Enough room for coding agents; fit offloads weights rather
              # than shrink it.
              ctx-size = 65536;
              # Hide the cache entries of the models below from /models.
              dedup-cache-models = true;
            };
            # Unsloth Dynamic 4-bit quants keep the sensitive layers at higher
            # precision, with the fixed chat templates.
            # MoE, 35B with 3B active, with image input: the strongest model
            # with ~3B active parameters for coding and agents. Qwen's
            # settings for coding; agents keep earlier reasoning, which fixes
            # truncated tool calls and lets the prompt cache be reused.
            "qwen3.6-35b-a3b" = {
              hf-repo = "unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q4_K_XL";
              temp = 0.6;
              top-p = 0.95;
              top-k = 20;
              min-p = 0;
              chat-template-kwargs = ''{"preserve_thinking":true}'';
            };
            # Small and fast, with image input; fits the desktop GPU whole.
            "gemma-4-e4b" = {
              hf-repo = "unsloth/gemma-4-E4B-it-GGUF:UD-Q4_K_XL";
              temp = 1.0;
              top-p = 0.95;
              top-k = 64;
            };
          };
        }
      );
      # One model at a time keeps memory for the desktop session.
      models-max = 1;
      sleep-idle-seconds = 600;
    };
  };
}
