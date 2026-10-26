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
            # MoE, 30B with 3B active: the coding and agent model.
            "glm-4.7-flash".hf-repo = "ggml-org/GLM-4.7-Flash-GGUF:Q4_K_M";
            # MoE, 21B with 3.6B active.
            "gpt-oss-20b".hf-repo = "ggml-org/gpt-oss-20b-GGUF";
            # Small and fast, with image input.
            "gemma-4-e4b".hf-repo = "ggml-org/gemma-4-E4B-it-GGUF";
          };
        }
      );
      # One model at a time keeps memory for the desktop session.
      models-max = 1;
      sleep-idle-seconds = 600;
    };
  };
}
