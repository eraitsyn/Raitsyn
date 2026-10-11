--!strict
-- Interface sounds. They use sounds that ship with the Roblox client
-- (rbxasset://), so the game needs no uploaded audio; swap any id here for
-- an uploaded asset to restyle. Volume follows the player's setting.

local SoundService = game:GetService("SoundService")

local State = require(script.Parent:WaitForChild("State"))

local Sfx = {}

local SOUNDS: { [string]: { id: string, volume: number } } = {
	click = { id = "rbxasset://sounds/clickfast.wav", volume = 0.5 },
	tick = { id = "rbxasset://sounds/clickfast.wav", volume = 0.25 },
	reveal = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.7 },
	buy = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5 },
	error = { id = "rbxasset://sounds/switch.wav", volume = 0.4 },
	big = { id = "rbxasset://sounds/snap.mp3", volume = 0.8 },
}

local group = Instance.new("SoundGroup")
group.Name = "RollRNGSfx"
group.Parent = SoundService

local templates: { [string]: Sound } = {}
for name, info in SOUNDS do
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = info.id
	sound.Volume = info.volume
	sound.SoundGroup = group
	sound.Parent = group
	templates[name] = sound
end

function Sfx.setVolume(volume: number)
	group.Volume = math.clamp(volume, 0, 1)
end

-- Plays a named sound. `pitch` shifts it (1 = unchanged) so repeated sounds,
-- like the reel ticking, do not sound identical.
function Sfx.play(name: string, pitch: number?)
	local template: Sound? = templates[name]
	if template == nil or group.Volume <= 0 then
		return
	end
	if pitch == nil or pitch == 1 then
		template:Play()
		return
	end
	local sound = template:Clone()
	sound.PlaybackSpeed = pitch
	sound.Parent = group
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

function Sfx.start()
	State.watch({ "settings" }, function()
		Sfx.setVolume(State.data.settings.sfxVolume)
	end)
end

return Sfx
