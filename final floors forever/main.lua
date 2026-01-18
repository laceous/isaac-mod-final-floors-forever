local mod = RegisterMod('Final Floors Forever', 1)
local json = require('json')
local game = Game()

mod.onGameStartHasRun = false
mod.maybeSpawnVoidPortal = false
mod.stateMegaSatanDoorOpened = 49 -- GameStateFlag.STATE_MEGA_SATAN_DOOR_OPENED

mod.state = {}
mod.state.applyToChallenges = false
mod.state.trapdoorOverChest = false
mod.state.guaranteeVoidPortal = false
mod.state.closeMegaSatanDoor = false

function mod:onGameStart()
  if mod:HasData() then
    local _, state = pcall(json.decode, mod:LoadData())
    
    if type(state) == 'table' then
      for _, v in ipairs({ 'applyToChallenges', 'trapdoorOverChest', 'guaranteeVoidPortal', 'closeMegaSatanDoor' }) do
        if type(state[v]) == 'boolean' then
          mod.state[v] = state[v]
        end
      end
    end
  end
  
  mod.onGameStartHasRun = true
end

function mod:onGameExit()
  mod:save()
  mod.onGameStartHasRun = false
  mod.maybeSpawnVoidPortal = false
end

function mod:save()
  mod:SaveData(json.encode(mod.state))
end

function mod:onNewLevel()
  if not REPENTANCE_PLUS then
    return
  end
  
  if game:IsGreedMode() or (not mod.state.applyToChallenges and mod:isAnyChallenge()) then
    return
  end
  
  local level = game:GetLevel()
  
  if level:GetStage() == LevelStage.STAGE6 and mod.state.closeMegaSatanDoor then
    game:SetStateFlag(mod.stateMegaSatanDoorOpened, false)
  end
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
    
    if mod.state.guaranteeVoidPortal then
      local room = game:GetRoom()
      mod:spawnVoidPortal(room:GetGridPosition(97))
    end
  end
end

-- filtered to PICKUP_BIGCHEST and PICKUP_TROPHY
function mod:onPickupInit(pickup)
  if not mod.onGameStartHasRun then
    return
  end
  
  if game:IsGreedMode() or (not mod.state.applyToChallenges and mod:isAnyChallenge()) then
    return
  end
  
  local level = game:GetLevel()
  local room = level:GetCurrentRoom()
  
  if mod:isIsaacOrSatan() then
    if mod.state.trapdoorOverChest and room:GetFrameCount() > -1 then
      pickup:Remove()
      mod:spawnTrapdoor(pickup.Position)
    end
  elseif mod:isBlueBabyOrTheLamb() then
    local chestIdx = level:IsAltStage() and 66 or 68
    local trapdoorIdx = level:IsAltStage() and 68 or 66
    
    pickup.Position = room:GetGridPosition(chestIdx)
    mod:spawnTrapdoor(room:GetGridPosition(trapdoorIdx))
    mod.maybeSpawnVoidPortal = true -- the game might spawn in a void portal, but it hasn't happened yet
  elseif mod:isDelirium() then
    local pos = room:GetGridPosition(room:GetGridIndex(pickup.Position) + (2 * room:GetGridWidth())) -- 2 spaces below chest
    mod:spawnVoidPortal(pos)
  end
end

-- ??? spawns void portal seed: B92E 983G (hard)
function mod:hasVoidPortal()
  local room = game:GetRoom()
  
  for i = 0, room:GetGridSize() - 1 do
    local gridEntity = room:GetGridEntity(i)
    if gridEntity and gridEntity:GetType() == GridEntityType.GRID_TRAPDOOR and gridEntity:GetVariant() == 1 then
      return true
    end
  end
  
  return false
end

function mod:spawnVoidPortal(pos)
  if not mod:hasVoidPortal() then
    local room = game:GetRoom()
    
    local portal = Isaac.GridSpawn(GridEntityType.GRID_TRAPDOOR, 1, pos, true)
    if portal:GetType() ~= GridEntityType.GRID_TRAPDOOR then
      mod:removeGridEntity(room:GetGridIndex(pos), 0, false, true)
      portal = Isaac.GridSpawn(GridEntityType.GRID_TRAPDOOR, 1, pos, true)
    end
    
    portal.VarData = 1
    portal:GetSprite():Load('gfx/grid/voidtrapdoor.anm2', true)
  end
end

function mod:spawnTrapdoor(pos)
  local level = game:GetLevel()
  local room = level:GetCurrentRoom()
  
  if level:IsAltStage() then
    if #Isaac.FindByType(EntityType.ENTITY_EFFECT, EffectVariant.HEAVEN_LIGHT_DOOR, 0, false, false) == 0 then
      Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.HEAVEN_LIGHT_DOOR, 0, pos, Vector.Zero, nil)
    end
  else
    local trapdoor = Isaac.GridSpawn(GridEntityType.GRID_TRAPDOOR, 0, pos, true)
    if trapdoor:GetType() ~= GridEntityType.GRID_TRAPDOOR then -- deal with reversed tower card which might have spawned a rock here
      mod:removeGridEntity(room:GetGridIndex(pos), 0, false, true)
      Isaac.GridSpawn(GridEntityType.GRID_TRAPDOOR, 0, pos, true)
    end
  end
end

function mod:removeGridEntity(gridIdx, pathTrail, keepDecoration, update)
  local room = game:GetRoom()
  
  if REPENTOGON then
    room:RemoveGridEntityImmediate(gridIdx, pathTrail, keepDecoration)
  else
    room:RemoveGridEntity(gridIdx, pathTrail, keepDecoration)
    if update then
      room:Update()
    end
  end
end

function mod:isAnyChallenge()
  return Isaac.GetChallenge() ~= Challenge.CHALLENGE_NULL or
         (REPENTOGON and game:GetSeeds():IsCustomRun() and DailyChallenge.GetChallengeParams():GetEndStage() > 0)
end

function mod:isIsaacOrSatan()
  local level = game:GetLevel()
  local roomDesc = level:GetCurrentRoomDesc()
  
  return level:GetStage() == LevelStage.STAGE5 and
         roomDesc.Data.Type == RoomType.ROOM_BOSS and
         roomDesc.GridIndex >= 0
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
  for _, v in ipairs({
                      { field = 'applyToChallenges'  , txtTrue = 'Apply to challenges'  , txtFalse = 'Do not apply to challenges'  , info = { 'Should this mod be applied to challenges?' } },
                      { field = 'trapdoorOverChest'  , txtTrue = 'Spawn trapdoor'       , txtFalse = 'Do not spawn trapdoor'       , info = { 'Do you want to spawn a trapdoor rather than', 'a chest after defeating Isaac or Satan?' } },
                      { field = 'guaranteeVoidPortal', txtTrue = 'Guarantee void portal', txtFalse = 'Do not guarantee void portal', info = { 'Do you want to guarantee the void portal', 'after defeating ??? or The Lamb?' } },
                      { field = 'closeMegaSatanDoor' , txtTrue = 'Close mega satan door', txtFalse = 'Do not close mega satan door', info = { 'In rep+, do you want to close the', 'Mega Satan door when looping?' } },
                    })
  do
    ModConfigMenu.AddSetting(
      mod.Name,
      'Settings',
      {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function()
          return mod.state[v.field]
        end,
        Display = function()
          return mod.state[v.field] and v.txtTrue or v.txtFalse
        end,
        OnChange = function(b)
          mod.state[v.field] = b
          mod:save()
        end,
        Info = v.info
      }
    )
  end
end
-- end ModConfigMenu --

mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.onGameStart)
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.onGameExit)
mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, mod.onNewLevel)
mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.onNewRoom)
mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.onUpdate)
mod:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT, mod.onPickupInit, PickupVariant.PICKUP_BIGCHEST)
mod:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT, mod.onPickupInit, PickupVariant.PICKUP_TROPHY)

if ModConfigMenu then
  mod:setupModConfigMenu()
end