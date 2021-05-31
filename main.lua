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
function Planet:getNearest(aClass,x,y)
  local closestObject
  local clostestDist2

  for _, contact in ipairs(self.body:getContacts()) do
    local fixtureA, fixtureB = contact:getFixtures()
    local object = fixtureA:getUserData()
    if instanceOf(aClass, object) then
      local dist2 = vec.dist2(self.body:getX(), self.body:getY(), object.body:getX(), object.body:getY())
      if clostestDist2 == nil or clostestDist2 > dist2 then
        clostestDist2 = dist2
        closestObject = object
      end
    end
  end
  local dir = 0
  if closestObject then
    local tx,ty = closestObject.body:getPosition()
    dir = self:getDirToTarget(x,y,tx,ty)
  end
  return closestObject, dir
end
function Planet:getDirToTarget(x,y,tx,ty)
  local px,py = self.body:getPosition()
  local d = vec.dot(tx-px,ty-py,-(y-py),x-px)
  return d > 0 and 1 or -1
end

KeyController = class('KeyController')
function KeyController:initialize(keyLeft, keyRight, keyShoot)
  self.keyLeft = keyLeft
  self.keyRight = keyRight
  self.keyShoot = keyShoot
end
function KeyController:update(dt)
  if love.keyboard.isDown(self.keyLeft) then
    self.player:move(-1)
  elseif love.keyboard.isDown(self.keyRight) then
    self.player:move(1)
  else
    self.player:move(0)
  end

  if love.keyboard.isDown(self.keyShoot) and self.lastShootKey == false then
    self.player:shoot()
  end
  self.lastShootKey = love.keyboard.isDown(self.keyShoot)
end
function KeyController:draw()
end

AIController = class('AIController')
function AIController:initialize(enemy)
  self.enemy = enemy
end
function AIController:update(dt)
  local player = self.player
  if player.junk then
    local ex,ey = self.enemy.body:getPosition()
    local vx,vy = vec.normalize(self.player.body:getLinearVelocity())
    local dx,dy = vec.normalize(vec.sub(ex,ey,self.player.body:getPosition()))
    if vec.dot(vx,vy,dx,dy) > math.cos(10/180*math.pi) then
      self.player:shoot()
    end
  else
    local junk, dir = player.planet:getNearest(Junk, player.body:getPosition())
    if junk then
      player:move(dir)
    else
      -- TODO: Add IDLE logic
      player:move(0)
    end
  end
end
function AIController:draw()

end

Player = class('Player')
Player.radius = 20
Player.speed = 300
Player.image = love.graphics.newImage('assets/sad-crab.png')
function Player:initialize(world,planet,controller)
  self.body = love.physics.newBody(gWorld,planet.body:getX(),planet.body:getY()-planet.radius-self.radius, 'dynamic')
  self.shape = love.physics.newCircleShape(self.radius)
  self.fixture = love.physics.newFixture(self.body, self.shape, 1)
  self.body:setMass(0.2)
  self.fixture:setFriction(0)
  self.fixture:setUserData(self)
  self.planet=planet
  self.fixture:setGroupIndex(-1)
  self.body:setFixedRotation(true)
  self.controller = controller
  self:move(0)
  controller.player = self
end
function Player:move(dir)
  self.dir = dir
end
function Player:update(dt)
  self.controller:update(dt)
  local dx,dy = self.body:getX() - self.planet.body:getX(), self.body:getY() - self.planet.body:getY()
  local angle = math.atan2(dx,-dy)
  self.normal = angle-math.pi/2
  local speed = self.speed
  local angle2 = math.pi/10 * self.dir
  self.body:setLinearVelocity(self.dir*math.cos(angle+angle2)*speed,self.dir*math.sin(angle+angle2)*speed)

  angle = angle + math.sin(love.timer.getTime() * self.speed/8)*math.pi/10*(self.dir)
  self.body:setAngle(angle)

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
        --other:destroy()
        self:takeOwnership(other)
      end
    end
  end
end
function Player:takeOwnership(junk)
  self.junk = junk
  local x,y = vec.add(self.body:getX(), self.body:getY(), vec.fromPolar(self.normal,self.radius))
  self.junk:getBody():setPosition(x,y)
  self.junkJoint = love.physics.newWeldJoint(self.body, self.junk:getBody(), x, y, false)
end
function Player:draw()
  local scale = self.radius / self.image:getWidth() * 2 * 1.5
  local rot = self.body:getAngle()
  love.graphics.setColor(1,0.5,0.5)
  love.graphics.draw(self.image,self.body:getX(),self.body:getY(),rot,scale,nil,self.image:getWidth()/2,self.image:getHeight()/2)
  love.graphics.setColor(1,1,1)
  self.controller:draw()
end

function Player:shoot()
  if self.junk then
    local dx,dy = vec.fromPolar(self.normal,1)
    local px,py = vec.mul((Junk.radius+self.radius)*1.1,dx,dy)
    local pvx,pvy = self.body:getLinearVelocity()
    local vx,vy = vec.add(pvx,pvy,vec.mul(300,dx,dy))
    local x,y = vec.add(px,py,self.body:getPosition())
    self.junk:getUserData():shoot(vx,vy)
    self.junkJoint:destroy()
    self.junkJoint = nil
    self.junk = nil
  end
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
function Junk:shoot(vx,vy)
  self.body:setLinearVelocity(vx,vy)
  self.suppresscolide = 0.2
  self.fixture:setGroupIndex(-1)
end
function Junk:update(dt)
  if self.suppresscolide then
    self.suppresscolide = self.suppresscolide - dt
    if self.suppresscolide < 0 then
      self.suppresscolide = nil
      self.fixture:setGroupIndex(0)
    end
  end
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
local player1 = Player(gWorld,planet1,KeyController('a','d','space'))
local player2 = Player(gWorld,planet2,AIController(player1))

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
  if button == 2 and not player1.junk then
    player1:takeOwnership(Junk(gWorld,0,0,0,0).fixture)
  end
end

function love.keypressed(key)
end
