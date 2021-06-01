

local spaceImage = love.graphics.newImage('assets/space.jpg')

love.physics.setMeter(100)

local G = 30000
local atmosphere = 30

Level = class("Level")
Level.victorysound = love.audio.newSource('assets/sound_hurray.ogg', 'stream')
function Level:initialize()
  self.time = -3
end
function Level:update(dt)
  local dt = math.min(dt,0.1)
  self.time = self.time + dt
  if self.time > 0 then
    for _, body in pairs(self.world:getBodyList()) do
      for _, fixture in pairs(body:getFixtureList()) do
        local userdata = fixture:getUserData()
        if userdata and userdata.update then
          userdata:update(dt)
        end
      end
    end

    for i, body1 in pairs(self.world:getBodyList()) do
      for j, body2 in pairs(self.world:getBodyList()) do
        if i ~= j then
          local dx, dy = body1:getX() - body2:getX(), body1:getY() - body2:getY()
          local r2 = dx*dx + dy*dy
          local r = math.sqrt(r2)
          local m1,m2 = body1:getMass(), body2:getMass()
          local f = m1*m2 / (r2) * G
          dx = dx / r
          dy = dy / r
          body1:applyForce(-f*dx, -f*dy)

          if body1 ~= planet1 and body1 ~= planet2 and body2 == planet1 or body2 == planet2 then
            if r < planet1.shape:getRadius() + atmosphere then
              body1:setLinearDamping(10)
            else
              body1:setLinearDamping(0)
            end
          end
        end
      end
    end
  
    for _,planet in ipairs(self.planets) do
      if planet.junk == 0 then
        love.audio.play(self.victorysound)
        Gamestate.switch(WinScreen(),planet)
        break
      end
    end
  end
  self.world:update(dt)
end
local bigFont = love.graphics.newFont(80)
function Level:draw()

  love.graphics.draw(spaceImage)
  for _, body in pairs(self.world:getBodyList()) do
    for _, fixture in pairs(body:getFixtureList()) do
      local userdata = fixture:getUserData()
      if userdata and userdata.draw then
        userdata:draw()
      else
        local shape = fixture:getShape()

        if shape:typeOf("CircleShape") then
            local cx, cy = body:getWorldPoints(shape:getPoint())
            love.graphics.circle("fill", cx, cy, shape:getRadius())
        elseif shape:typeOf("PolygonShape") then
            love.graphics.polygon("fill", body:getWorldPoints(shape:getPoints()))
        else
            love.graphics.line(body:getWorldPoints(shape:getPoints()))
        end
      end
    end
  end

  if self.time < 0 then 
    love.graphics.print(math.floor(-self.time),bigFont,love.graphics.getWidth()/2,love.graphics.getHeight()/2,0,math.max(0,math.cos(math.fmod(-self.time,1)*2)+1),nil,20)
  end

end

Level1 = class('Level1', Level)
function Level1:enter(from, numPlayers)
  self.world = love.physics.newWorld()
  self.world:setGravity(0,0)
  self.numPlayers = numPlayers

  self.planets = {
    Planet(self.world,400,720-200,{1,0.5,0.5}, 'Red'),
    Planet(self.world,880,720-200,{0.1,0.7,1.0}, 'Blue'),
    Planet(self.world,640,200,{1,1.0,0.5},'Yellow'),
  }
  local controllers = {
    KeyController('a','d','w', 'left'),
    KeyController('j','l','i', 'right')
  }
  local players = {}
  for i,planet in ipairs(self.planets) do
    if i <= numPlayers then
      table.insert(players, Player(self.world, planet, controllers[i]))
    else
      table.insert(players, Player(self.world, planet, AIController()))
    end
  end

  for i,player in pairs(players) do
    if instanceOf(AIController, players[i].controller) then
      for j,enemy in ipairs(players) do
        if j ~= i then
          player.controller:addEnemy(enemy)
        end
      end
    end
  end

end