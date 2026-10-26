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
            # Unsloth Dynamic 4-bit quants, which keep the sensitive layers at
            # higher precision.
            # MoE, 35B with 3B active: the coding and agent model.
            "qwen3.6-35b-a3b".hf-repo = "unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q4_K_XL";
            # MoE, 26B with 4B active, with image input.
            "gemma-4-26b-a4b".hf-repo = "unsloth/gemma-4-26B-A4B-it-GGUF:UD-Q4_K_XL";
            # Small and fast, with image input; fits the desktop GPU whole.
            "gemma-4-e4b".hf-repo = "unsloth/gemma-4-E4B-it-GGUF:UD-Q4_K_XL";
          };
        }
      );
      # One model at a time keeps memory for the desktop session.
      models-max = 1;
      sleep-idle-seconds = 600;
    };
  };
}
