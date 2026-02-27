local love = require "love"

function AudioManager()
  return {
    bgm = nil,
    laserSfx = nil,
    explosionSfx = nil,
    _oneshots = {},

    load = function(self)
      self.bgm = love.audio.newSource("assets/background.mp3", "stream")
      self.bgm:setLooping(true)

      self.laserSfx = love.audio.newSource("assets/lasers.mp3", "static")
      self.explosionSfx = love.audio.newSource("assets/explosion.mp3", "static")
    end,

    playBackground = function(self)
      if not self.bgm then
        return
      end

      if not self.bgm:isPlaying() then
        self.bgm:play()
      end
    end,

    _playOneShot = function(self, template, opts)
      if not template then
        return
      end

      local s = template:clone()
      s:setLooping(false)

      if opts and opts.seekSeconds then
        s:seek(opts.seekSeconds, "seconds")
      end

      s:play()
      self._oneshots[#self._oneshots + 1] = s
    end,

    playLaser = function(self)
      self:_playOneShot(self.laserSfx)
    end,

    playExplosion = function(self)
      -- The explosion MP3 has silence/lead-in; the actual sound starts at 0:04.
      self:_playOneShot(self.explosionSfx, { seekSeconds = 4 })
    end,

    update = function(self)
      -- Keep the list small so finished one-shots can be GC'd.
      for i = #self._oneshots, 1, -1 do
        if not self._oneshots[i]:isPlaying() then
          table.remove(self._oneshots, i)
        end
      end
    end
  }
end

return AudioManager
