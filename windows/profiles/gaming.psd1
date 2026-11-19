# Games and their launchers; only desktop includes this layer.
@{
    Winget   = @(
        'Valve.Steam'
        @{ Id = 'Blizzard.BattleNet'; Args = @('--location', 'C:\Program Files (x86)\Battle.net') }
        'PrismLauncher.PrismLauncher'
        'WowUp.CF'
        'Ubisoft.Connect'
        'EpicGames.EpicGamesLauncher'
        # The Riot Client comes by hand (windows/README.md): winget has only
        # Riot's game installers, which register their game too.
        'Discord.Discord'
        'Microsoft.VCRedist.2015+.x64'
        'Microsoft.VCRedist.2015+.x86'
    )
    Registry = @('gaming.reg')
}
