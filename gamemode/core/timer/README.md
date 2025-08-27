# Black Mesa Deathmatch Timer System

## Overview
The timer system manages round-based gameplay with 10-minute rounds and 60-second intermissions.

## Features
- **10-minute rounds**: Each round lasts exactly 10 minutes
- **60-second intermissions**: 60-second break between rounds
- **Green Arial font display**: Digital clock-style timer in bright green
- **Automatic round cycling**: Rounds automatically start and end
- **Main menu forcing**: All players are forced to the main menu during intermission
- **Entity management**: Entities are cleared and respawned at round start

## Timer Display
- **Round timer**: Shows MM:SS format (e.g., "09:45")
- **Intermission timer**: Shows MM:SS:SS format with milliseconds (e.g., "00:45:23")
- **Round information**: Displays current round number
- **Warning system**: Flashes red when time is low (last 30 seconds)

## Console Commands

### Admin Commands
- `bm_dm_timer_force_end` - Force end current round (Admin only)
- `bm_dm_timer_force_start` - Force start new round (Admin only)

### Client Commands
- `bm_dm_timer_toggle` - Toggle timer visibility
- `bm_dm_timer_test` - Set test timer (5 minutes)

## Configuration
Timer settings can be modified in `sv_timer.lua`:
- `RoundDuration`: 600 seconds (10 minutes)
- `IntermissionDuration`: 60 seconds
- `RoundStartDelay`: 5 seconds initial delay

## Integration
The timer system integrates with:
- **Entity Spawner**: Pauses during intermission, clears entities on round start
- **Main Menu**: Forces players to menu during intermission
- **Player Spawn**: Prevents spawning during intermission

## Network Messages
- `BM_DM_Timer_Update` - Timer updates
- `BM_DM_Timer_RoundStart` - Round start notification
- `BM_DM_Timer_RoundEnd` - Round end notification
- `BM_DM_Timer_ShowMenu` - Force show main menu

## Hooks
- `BM_DM_RoundStart` - Called when a new round starts
- `BM_DM_RoundEnd` - Called when a round ends
