local mod = RegisterMod('Final Floors Forever', 1)
local json = require('json')
local game = Game()

mod.maybeSpawnVoidPortal = false

mod.state = {}
mod.state.applyToChallenges = false
mod.state.guaranteeVoidPortal = false

function mod:onGameStart()
  if mod:HasData() then
    local _, state = pcall(json.decode, mod:LoadData())
    
    if type(state) == 'table' then
      if type(state.applyToChallenges) == 'boolean' then
        mod.state.applyToChallenges = state.applyToChallenges
      end
      if type(state.guaranteeVoidPortal) == 'boolean' then
        mod.state.guaranteeVoidPortal = state.guaranteeVoidPortal
      end
    end
  end
end

function mod:onGameExit()
  mod:save()
  mod.maybeSpawnVoidPortal = false
end

function mod:save()
  mod:SaveData(json.encode(mod.state))
end

function mod:onNewRoom()
  mod.maybeSpawnVoidPortal = false
end

function mod:onUpdate()
  if game:IsGreedMode() or (not mod.state.applyToChallenges and mod:isAnyChallenge()) then
    return
  end
  
  if mod.maybeSpawnVoidPortal then
    mod.maybeSpawnVoidPortal = false
    
    if mod.state.guaranteeVoidPortal and not mod:hasVoidPortal() then
      local room = game:GetRoom()
      mod:spawnVoidPortal(room:GetGridPosition(97))
    end
  end
end

-- filtered to PICKUP_BIGCHEST and PICKUP_TROPHY
function mod:onPickupInit(pickup)
  if game:IsGreedMode() or (not mod.state.applyToChallenges and mod:isAnyChallenge()) then
    return
  end
  
  local level = game:GetLevel()
  local room = level:GetCurrentRoom()
  
  if mod:isBlueBabyOrTheLamb() then
    local chestIdx = level:IsAltStage() and 66 or 68
    local trapdoorIdx = level:IsAltStage() and 68 or 66
    
    pickup.Position = room:GetGridPosition(chestIdx)
    mod:spawnTrapdoor(room:GetGridPosition(trapdoorIdx))
    mod.maybeSpawnVoidPortal = true -- the game might spawn in a void portal, but it hasn't happened yet
  elseif mod:isDelirium() then
    local pos = room:GetGridPosition(room:GetGridIndex(pickup.Position) + (2 * 28)) -- 2 spaces below chest
    mod:spawnVoidPortal(pos)
  end
end

-- ??? spawns void portal seed: B92E 983G (hard)
function mod:hasVoidPortal()
  local room = game:GetRoom()
  
  for i = 16, 118 do -- 1x1 room
    local gridEntity = room:GetGridEntity(i)
    if gridEntity and gridEntity:GetType() == GridEntityType.GRID_TRAPDOOR and gridEntity:GetVariant() == 1 then
      return true
    end
  end
  
  return false
end

function mod:spawnVoidPortal(pos)
  local portal = Isaac.GridSpawn(GridEntityType.GRID_TRAPDOOR, 1, Isaac.GetFreeNearPosition(pos, 3), true)
  portal.VarData = 1
  portal:GetSprite():Load('gfx/grid/voidtrapdoor.anm2', true)
end

function mod:spawnTrapdoor(pos)
  local level = game:GetLevel()
  
  if level:IsAltStage() then
    if #Isaac.FindByType(EntityType.ENTITY_EFFECT, EffectVariant.HEAVEN_LIGHT_DOOR, 0, false, false) == 0 then
      Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.HEAVEN_LIGHT_DOOR, 0, pos, Vector.Zero, nil)
    end
  else
    Isaac.GridSpawn(GridEntityType.GRID_TRAPDOOR, 0, pos, true)
  end
end

function mod:isAnyChallenge()
  return Isaac.GetChallenge() ~= Challenge.CHALLENGE_NULL
end

function mod:isBlueBabyOrTheLamb()
  local level = game:GetLevel()
  local roomDesc = level:GetCurrentRoomDesc()
  
  return level:GetStage() == LevelStage.STAGE6 and
         roomDesc.Data.Type == RoomType.ROOM_BOSS and
         roomDesc.GridIndex >= 0
end

function mod:isDelirium()
  local level = game:GetLevel()
  local roomDesc = level:GetCurrentRoomDesc()
  
  return level:GetStage() == LevelStage.STAGE7 and
         roomDesc.Data.Type == RoomType.ROOM_BOSS and
         roomDesc.Data.Shape == RoomShape.ROOMSHAPE_2x2 and
         roomDesc.GridIndex >= 0
end

-- start ModConfigMenu --
function mod:setupModConfigMenu()
  for _, v in ipairs({ 'Settings' }) do
    ModConfigMenu.RemoveSubcategory(mod.Name, v)
  end
  ModConfigMenu.AddSetting(
    mod.Name,
    'Settings',
    {
      Type = ModConfigMenu.OptionType.BOOLEAN,
      CurrentSetting = function()
        return mod.state.applyToChallenges
      end,
      Display = function()
        return (mod.state.applyToChallenges and 'Apply' or 'Do not apply') .. ' to challenges'
      end,
      OnChange = function(b)
        mod.state.applyToChallenges = b
        mod:save()
      end,
      Info = { 'Should this mod be applied to challenges?' }
    }
  )
  ModConfigMenu.AddSetting(
    mod.Name,
    'Settings',
    {
      Type = ModConfigMenu.OptionType.BOOLEAN,
      CurrentSetting = function()
        return mod.state.guaranteeVoidPortal
      end,
      Display = function()
        return (mod.state.guaranteeVoidPortal and 'Guarantee' or 'Do not guarantee') .. ' void portal'
      end,
      OnChange = function(b)
        mod.state.guaranteeVoidPortal = b
        mod:save()
      end,
      Info = { 'Do you want to guarantee the void portal', 'after defeating ??? or The Lamb?' }
    }
  )
end
-- end ModConfigMenu --

mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.onGameStart)
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.onGameExit)
mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.onNewRoom)
mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.onUpdate)
mod:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT, mod.onPickupInit, PickupVariant.PICKUP_BIGCHEST)
mod:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT, mod.onPickupInit, PickupVariant.PICKUP_TROPHY)

if ModConfigMenu then
  mod:setupModConfigMenu()
end