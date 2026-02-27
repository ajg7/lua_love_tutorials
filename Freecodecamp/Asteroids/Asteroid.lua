local love = require "love"

local function randRange(min, max)
	return min + (max - min) * love.math.random()
end

local function clampSize(size)
	if size == 1 or size == 2 or size == 3 then
		return size
	end
	return 3
end

local function makeJaggedPoints(radius)
	local points = {}
	local vertexCount = love.math.random(10, 14)
	for i = 1, vertexCount do
		local angle = (i / vertexCount) * (math.pi * 2)
		local r = radius * randRange(0.65, 1.0)
		points[#points + 1] = r * math.cos(angle)
		points[#points + 1] = r * math.sin(angle)
	end
	return points
end

local RADII = {
	[3] = 55,
	[2] = 32,
	[1] = 18
}

function Asteroid(size, x, y)
	size = clampSize(size)
	local radius = RADII[size]

	local w = love.graphics.getWidth()
	local h = love.graphics.getHeight()

	local speed
	if size == 3 then
		speed = randRange(35, 75)
	elseif size == 2 then
		speed = randRange(55, 105)
	else
		speed = randRange(80, 150)
	end

	local direction = randRange(0, math.pi * 2)
	local dx = speed * math.cos(direction)
	local dy = speed * math.sin(direction)

	local points = makeJaggedPoints(radius)

	return {
		size = size,
		x = x or randRange(0, w),
		y = y or randRange(0, h),
		radius = radius,
		dx = dx,
		dy = dy,
		angle = randRange(0, math.pi * 2),
		rotSpeed = randRange(-1.2, 1.2),
		points = points,

		update = function(self, dt)
			self.x = self.x + self.dx * dt
			self.y = self.y + self.dy * dt
			self.angle = self.angle + self.rotSpeed * dt

			local screen_w = love.graphics.getWidth()
			local screen_h = love.graphics.getHeight()
			local r = self.radius

			if self.x < -r then
				self.x = screen_w + r
			elseif self.x > screen_w + r then
				self.x = -r
			end

			if self.y < -r then
				self.y = screen_h + r
			elseif self.y > screen_h + r then
				self.y = -r
			end
		end,

		draw = function(self, debugging)
			if debugging then
				love.graphics.setColor(1, 0, 0, 1)
				love.graphics.circle("line", self.x, self.y, self.radius)
			end

			local cosA = math.cos(self.angle)
			local sinA = math.sin(self.angle)
			local verts = {}

			for i = 1, #self.points, 2 do
				local px = self.points[i]
				local py = self.points[i + 1]

				local rx = px * cosA - py * sinA
				local ry = px * sinA + py * cosA

				verts[#verts + 1] = self.x + rx
				verts[#verts + 1] = self.y + ry
			end

			love.graphics.setColor(1, 1, 1, 1)
			love.graphics.polygon("line", verts)
		end,

		split = function(self)
			if self.size <= 1 then
				return {}
			end

			local nextSize = self.size - 1
			local a1 = Asteroid(nextSize, self.x, self.y)
			local a2 = Asteroid(nextSize, self.x, self.y)

			-- Add a small “burst” so the children separate nicely.
			local burst = randRange(35, 80)
			local theta = randRange(0, math.pi * 2)
			a1.dx = a1.dx + burst * math.cos(theta)
			a1.dy = a1.dy + burst * math.sin(theta)
			a2.dx = a2.dx - burst * math.cos(theta)
			a2.dy = a2.dy - burst * math.sin(theta)

			return { a1, a2 }
		end
	}
end

return Asteroid
