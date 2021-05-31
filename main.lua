--
-- Copyright DrJamgo@hotmail.com 2021
--
love.filesystem.setRequirePath("?.lua;?/init.lua;lua/?.lua;lua/?/init.lua")

if arg[#arg] == "-debug" then
  if pcall(require, "lldebugger") then require("lldebugger").start() end -- << vscode debugger
  if pcall(require, "mobdebug") then require("mobdebug").start() end -- << zerobrain debugger
end

require 'middleclass'
local vec = require 'hump.vector-light'

local spaceImage = love.graphics.newImage('assets/space.jpg')

Planet = class('Planet')
Planet.radius = 100
Planet.image = love.graphics.newImage('assets/world.png')
function Planet:initialize(world,x,y)
  self.body = love.physics.newBody(world, x,y, 'dynamic')
  self.shape = love.physics.newCircleShape(self.radius)
  self.fixture = love.physics.newFixture(self.body, self.shape, 1000)
  self.body:setMass(1000)
  self.fixture:setFriction(10)
  self.fixture:setUserData(self)
  self.x,self.y = x,y
end
function Planet:update(dt)
  self.body:setPosition(self.x,self.y)
  self.body:setLinearVelocity(0,0)
end
function Planet:draw()
  local scale = self.radius / self.image:getWidth() * 2
  love.graphics.setColor(0.1,0.5,1.0)
  love.graphics.draw(self.image,self.x,self.y,0,scale,nil,self.image:getWidth()/2,self.image:getHeight()/2)
  love.graphics.setColor(1,1,1)
end

Player = class('Player')
Player.radius = 20
Player.speed = 300
Player.image = love.graphics.newImage('assets/sad-crab.png')
function Player:initialize(world,planet)
  self.body = love.physics.newBody(gWorld,planet.body:getX(),planet.body:getY()-planet.radius-self.radius, 'dynamic')
  self.shape = love.physics.newCircleShape(self.radius)
  self.fixture = love.physics.newFixture(self.body, self.shape, 1)
  self.body:setMass(0.2)
  self.fixture:setFriction(1)
  self.fixture:setUserData(self)
  self.planet=planet
end
function Player:update(dt)
  local dx,dy = self.body:getX() - self.planet.body:getX(), self.body:getY() - self.planet.body:getY()
  self.dir = math.atan2(dx,-dy)
  self.normal = self.dir-math.pi/2
  local speed = self.speed
  if love.keyboard.isDown('a') then
    self.body:setLinearVelocity(-math.cos(self.dir)*speed,-math.sin(self.dir)*speed)
    self.move = true
  elseif love.keyboard.isDown('d') then
    self.body:setLinearVelocity(math.cos(self.dir)*speed,math.sin(self.dir)*speed)
    self.move = true
  else
    self.body:setLinearVelocity(0,0)
    self.move = nil
  end
  self.dir = self.dir + math.sin(love.timer.getTime() * self.speed/8)*math.pi/10*(self.move and 1 or 0)

  for _,contact in ipairs(self.body:getContacts()) do
    local me, other = contact:getFixtures()
    local nx,ny = contact:getNormal()
    if other == self.fixture then
      other, me = me, other
      nx,ny = -nx,-ny
    end
    local dx,dy = other:getBody():getX() - self.body:getX(), other:getBody():getY() - self.body:getY()
    if other ~= self.planet.fixture and contact:isTouching() and (dx*nx+dy*ny > 0) then
      if self.junk and other ~= self.junk then
        -- dead
      else
        other:destroy()
        self.junk = other
      end
    end
  end
end
function Player:draw()
  local scale = self.radius / self.image:getWidth() * 2 * 1.5
  local rot = self.dir
  love.graphics.setColor(1,0.5,0.5)
  love.graphics.draw(self.image,self.body:getX(),self.body:getY(),rot,scale,nil,self.image:getWidth()/2,self.image:getHeight()/2)
  if self.junk then
    love.graphics.setColor(Junk.color)
    local x,y = vec.add(self.body:getX(), self.body:getY(), vec.fromPolar(rot-math.pi/2,self.radius))
    love.graphics.circle("fill", x,y, Junk.radius)
  end
  love.graphics.setColor(1,1,1)
end
function Player:shoot()
  --local dx,dy = vec.normalize(x-player2.body:getX(),y-player2.body:getY())
  local dx,dy = vec.fromPolar(self.normal,1)
  local px,py = vec.mul((Junk.radius+self.radius)*1.1,dx,dy)
  local pvx,pvy = self.body:getLinearVelocity()
  local vx,vy = vec.add(pvx,pvy,vec.mul(300,dx,dy))
  local x,y = vec.add(px,py,self.body:getPosition())
  local Junk = Junk(gWorld,x,y,vx,vy)
  self.junk = nil
end

Junk = class('Junk')
Junk.radius = 10
Junk.color = {1,1,0.5}
function Junk:initialize(world,x,y,vx,vy)
  self.body = love.physics.newBody(gWorld, x,y, 'dynamic')
  self.shape = love.physics.newRectangleShape(self.radius*1.5,self.radius*1.5)
  self.fixture = love.physics.newFixture(self.body, self.shape, 1)
  self.body:setLinearVelocity(vx,vy)
  self.body:setMass(0.1)
  self.body:setFixedRotation(false)
  self.fixture:setUserData(self)
  self.fixture:setFriction(10)
  self.body:setAngularDamping(1)
end
function Junk:draw2()
  love.graphics.setColor(self.color)
  love.graphics.circle("fill", self.body:getX(), self.body:getY(), self.shape:getRadius())
  love.graphics.setColor(1,1,1)
end

love.physics.setMeter(100)
gWorld = love.physics.newWorld()
gWorld:setGravity(0,0)

local planet1 = Planet(gWorld,300,400)
local planet2 = Planet(gWorld,900,400)
local player2 = Player(gWorld,planet2)

function love.load()
end

local G = 15000
local atmosphere = 30

function love.update(dt)
  for _, body in pairs(gWorld:getBodies()) do
    for _, fixture in pairs(body:getFixtures()) do
      local userdata = fixture:getUserData()
      if userdata and userdata.update then
        userdata:update(dt)
      end
    end
  end

  for i, body1 in pairs(gWorld:getBodies()) do
    for j, body2 in pairs(gWorld:getBodies()) do
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

  gWorld:update(dt)
end

function love.draw()
  love.graphics.draw(spaceImage)
  for _, body in pairs(gWorld:getBodies()) do
    for _, fixture in pairs(body:getFixtures()) do
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
end

function love.mousepressed(x, y, button, istouch, presses)
  if button == 1 and player2.junk then
    player2:shoot()
  elseif button == 2 then
    player2.junk = true
  end
end

function love.keypressed(key)
end