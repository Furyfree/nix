# Games and their launchers; only desktop includes this layer.
@{
    Winget   = @(
        'Valve.Steam'
        @{ Id = 'Blizzard.BattleNet'; Args = @('--location', 'C:\Program Files (x86)\Battle.net') }
        'PrismLauncher.PrismLauncher'
        'WowUp.CF'
        'Ubisoft.Connect'
        'EpicGames.EpicGamesLauncher'
        # Each brings the Riot Client; League of Legends' ID picks its server.
        'RiotGames.LeagueOfLegends.EUW'
        'RiotGames.LeagueOfLegends.EUNE'
        'RiotGames.Valorant.EU'
        'Discord.Discord'
        'Microsoft.VCRedist.2015+.x64'
        'Microsoft.VCRedist.2015+.x86'
    )
    Registry = @('gaming.reg')
}
