# A developer's Windows for anyone: good settings and apps from winget, without
# Mise or my configs. It stands apart from vm, so some tools are in both: here
# from winget, there from Mise.
@{
    Include          = @('common')
    Winget           = @(
        'Brave.Brave'
        'Microsoft.PowerToys'
        'T3Tools.T3Code'
        'Microsoft.VisualStudioCode'
        'Anthropic.ClaudeCode'
        'OpenAI.Codex'
        'GitHub.cli'
        'astral-sh.uv'
        'OpenJS.NodeJS.LTS'
        'Amazon.Corretto.25.JDK'
        'Microsoft.DotNet.SDK.10'
        'BurntSushi.ripgrep.MSVC'
        'sharkdp.fd'
        'junegunn.fzf'
        'sharkdp.bat'
        'jqlang.jq'
        'MikeFarah.yq'
        'JesseDuffield.lazygit'
        'Casey.Just'
    )
    Registry         = @('brave.reg')
    Extensions       = @{ code = @('ms-vscode-remote.remote-wsl') }
    Wsl              = @{
        Distribution = 'Ubuntu'
        Apt          = @('build-essential', 'curl', 'unzip')
    }
}
