local love = require "love"
local Enemy = require "Enemy"
local Button = require "Freecodecamp.Asteroids.ui.components.Button"

math.randomseed(os.time())

local player = {
  radius = 20,
  x = 30,
  y = 30
}

local game = {
  difficulty = 1,
  state = {
    menu = true,
    settings = false,
    paused = false,
    running = false,
    ended = false
  }
}

local buttons = {
  menu_state = {},
  settings_state = {}
}

local enemies = {}

local score = 0
local score_timer = 0

local settings = {
  player_color = "white",
  enemy_color = "pink",
  difficulty = "easy",
}

local color_order = { "white", "grey", "pink", "purple", "green", "red", "blue" }
local color_map = {
  white = { 1, 1, 1 },
  grey = { 0.6, 0.6, 0.6 },
  pink = { 1, 0.5, 0.7 },
  purple = { 0.6, 0.3, 0.8 },
  green = { 0.2, 0.9, 0.2 },
  red = { 0.9, 0.2, 0.2 },
  blue = { 0.2, 0.4, 0.9 },
}

local function uppercaseWords(s)
  return (s:gsub("(%a)([%w_']*)", function(a, b) return a:upper() .. b:lower() end))
end

local function cycleSettingColor(field)
  local current = settings[field]
  local index = 1
  for i = 1, #color_order do
    if color_order[i] == current then
      index = i
      break
    end
  end
  index = index + 1
  if index > #color_order then
    index = 1
  end
  settings[field] = color_order[index]
end

local function cycleDifficulty()
  if settings.difficulty == "easy" then
    settings.difficulty = "medium"
  elseif settings.difficulty == "medium" then
    settings.difficulty = "hard"
  else
    settings.difficulty = "easy"
  end
end

local function getPlayerColor()
  return color_map[settings.player_color] or color_map.white
end

local function getEnemyColor()
  return color_map[settings.enemy_color] or color_map.pink
end

local function getEnemySpeed()
  if settings.difficulty == "medium" then
    return 1.5
  elseif settings.difficulty == "hard" then
    return 2
  end
  return 1
end

local function getSpawnIntervalPoints()
  if settings.difficulty == "hard" then
    return 5
  end
  return 10
end

local function refreshSettingsButtonText()
  if buttons.settings_state.player_color then
    buttons.settings_state.player_color.text = "Player Color: " .. uppercaseWords(settings.player_color)
  end
  if buttons.settings_state.enemy_color then
    buttons.settings_state.enemy_color.text = "Enemy Color: " .. uppercaseWords(settings.enemy_color)
  end
  if buttons.settings_state.difficulty then
    buttons.settings_state.difficulty.text = "Difficulty: " .. uppercaseWords(settings.difficulty)
  end
end

local function drawButtonsStack(order, bottom_margin, padding_y)
  if #order == 0 then
    return
  end

  bottom_margin = bottom_margin or 30
  padding_y = padding_y or 10

  local window_w = love.graphics.getWidth()
  local window_h = love.graphics.getHeight()

  local max_w = 0
  local total_h = 0
  for i = 1, #order do
    local button = order[i]
    if button.width > max_w then
      max_w = button.width
    end
    total_h = total_h + button.height
  end
  total_h = total_h + padding_y * (#order - 1)

  local start_x = (window_w - max_w) / 2
  local start_y = window_h - bottom_margin - total_h

  for i = 1, #order do
    local button = order[i]
    local y = start_y + (i - 1) * (button.height + padding_y)
    button:draw(start_x, y, start_x, y + 10)
  end
end

local function startGame()
  score = 0
  score_timer = 0
  enemies = { Enemy(getEnemySpeed(), getEnemyColor()) }

  game.state.menu = false
  game.state.settings = false
  game.state.paused = false
  game.state.ended = false
  game.state.running = true
end

local function endGame()
  game.state.running = false
  game.state.menu = true
  game.state.settings = false
  game.state.ended = true
end

local function openSettings()
  game.state.running = false
  game.state.menu = false
  game.state.settings = true
end

local function backToMenu()
  game.state.settings = false
  game.state.menu = true
end

local function isTouching(player_x, player_y, player_radius, enemy)
  local dx = player_x - enemy.x
  local dy = player_y - enemy.y
  local distance = math.sqrt(dx * dx + dy * dy)
  return distance <= (player_radius + enemy.radius)
end

local function separateEnemies()
  for i = 1, #enemies - 1 do
    for j = i + 1, #enemies do
      local a = enemies[i]
      local b = enemies[j]

      local dx = a.x - b.x
      local dy = a.y - b.y
      local dist = math.sqrt(dx * dx + dy * dy)
      local min_dist = a.radius + b.radius

      if dist < min_dist then
        local nx, ny
        if dist == 0 then
          nx, ny = 1, 0
          dist = 0.000001
        else
          nx, ny = dx / dist, dy / dist
        end

        local push = (min_dist - dist) / 2
        a.x = a.x + nx * push
        a.y = a.y + ny * push
        b.x = b.x - nx * push
        b.y = b.y - ny * push
      end
    end
  end
end

function love.load()
  love.window.setTitle("Save the Ball!!!")
  love.mouse.setVisible(false)

  buttons.menu_state.play_game = Button("Start Game", startGame, nil, 120, 40)
  buttons.menu_state.settings = Button("Settings", openSettings, nil, 120, 40)
  buttons.menu_state.exit_game = Button("Exit Game", love.event.quit, nil, 120, 40)

  buttons.settings_state.player_color = Button("Player Color: White", function()
    cycleSettingColor("player_color")
    refreshSettingsButtonText()
  end, nil, 260, 40)

  buttons.settings_state.enemy_color = Button("Enemy Color: Pink", function()
    cycleSettingColor("enemy_color")
    refreshSettingsButtonText()
  end, nil, 260, 40)

  buttons.settings_state.difficulty = Button("Difficulty: Easy", function()
    cycleDifficulty()
    refreshSettingsButtonText()
  end, nil, 260, 40)

  buttons.settings_state.back = Button("Back", backToMenu, nil, 120, 40)
  refreshSettingsButtonText()

  table.insert(enemies, 1, Enemy(getEnemySpeed(), getEnemyColor()))
end

function love.mousepressed(x, y, button, istouch, presses)
  if not game.state["running"] then
    if button == 1 then
      if game.state["menu"] then
        for index in pairs(buttons.menu_state) do
          buttons.menu_state[index]:checkPressed(x, y, button, istouch, presses)
        end
      elseif game.state["settings"] then
        for index in pairs(buttons.settings_state) do
          buttons.settings_state[index]:checkPressed(x, y, button, istouch, presses)
        end
      end
    end
  end
end

function love.update(dt)
  player.x, player.y = love.mouse.getPosition()

  if game.state.running then
    score_timer = score_timer + dt
    if score_timer >= 1 then
      local points_to_add = math.floor(score_timer)
      score = score + points_to_add
      score_timer = score_timer - points_to_add
    end

    local spawn_interval = getSpawnIntervalPoints()
    local desired_enemy_count = 1 + math.floor(score / spawn_interval)
    while #enemies < desired_enemy_count do
      table.insert(enemies, Enemy(getEnemySpeed(), getEnemyColor()))
    end

    local player_hit_radius = player.radius / 2
    for i = 1, #enemies do
      enemies[i]:move(player.x, player.y)
    end

    separateEnemies()

    for i = 1, #enemies do
      if isTouching(player.x, player.y, player_hit_radius, enemies[i]) then
        endGame()
        break
      end
    end
  end
end

function love.draw()
  love.graphics.printf(
  "FPS: " .. love.timer.getFPS(), 
    love.graphics.newFont(16), 
    10, 
    love.graphics.getHeight() - 30, 
    love.graphics.getWidth())

  love.graphics.printf(
    "Score: " .. score,
    love.graphics.newFont(18),
    10,
    10,
    love.graphics.getWidth())

  local player_color = getPlayerColor()
  if game.state["running"] then
      for i = 1, #enemies do
        enemies[i]:draw()
      end
      love.graphics.setColor(player_color[1], player_color[2], player_color[3])
      love.graphics.circle("fill", player.x, player.y, player.radius / 2)
      love.graphics.setColor(1, 1, 1)
  elseif game.state["menu"] then
    drawButtonsStack({
      buttons.menu_state.play_game,
      buttons.menu_state.settings,
      buttons.menu_state.exit_game,
    })

    if game.state.ended then
      love.graphics.printf(
        "Game Over",
        love.graphics.newFont(28),
        0,
        70,
        love.graphics.getWidth(),
        "center")
    end
  elseif game.state["settings"] then
    love.graphics.printf(
      "Settings",
      love.graphics.newFont(28),
      0,
      70,
      love.graphics.getWidth(),
      "center")

    drawButtonsStack({
      buttons.settings_state.player_color,
      buttons.settings_state.enemy_color,
      buttons.settings_state.difficulty,
      buttons.settings_state.back,
    })
  end

  if not game.state["running"] then
      love.graphics.setColor(player_color[1], player_color[2], player_color[3])
      love.graphics.circle("fill", player.x, player.y, player.radius)
      love.graphics.setColor(1, 1, 1)
  end
end