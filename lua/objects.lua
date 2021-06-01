
require 'middleclass'
local vec = require 'hump.vector-light'

function getOtherFixture(fixture, contact)
  me, other = contact:getFixtures()
  if other == fixture then
    other, me = me, other
  end
  return other
end

Planet = class('Planet')
Planet.radius = 80
Planet.image = love.graphics.newImage('assets/world.png')
function Planet:initialize(world,x,y,color,name)
  self.body = love.physics.newBody(world, x,y, 'dynamic')
  self.shape = love.physics.newCircleShape(self.radius)
  self.fixture = love.physics.newFixture(self.body, self.shape, 1000)
  self.body:setMass(500)
  self.fixture:setFriction(10)
  self.fixture:setUserData(self)
  self.x,self.y = x,y
  self.color = color
  self.world = world
  self.name = name
  for i = 1, 3 do
    local C = Junk
    C(world, vec.add(self.x,self.y,vec.randomDirection(self.radius+C.radius)))
  end
  for i = 1, 2 do
    local C = JunkBall
    C(world, vec.add(self.x,self.y,vec.randomDirection(self.radius+C.radius)))
  end
end
function Planet:update(dt)
  self.body:setPosition(self.x,self.y)
  self.body:setLinearVelocity(0,0)

  self.junk = 0

  for _, body in pairs(self.world:getBodyList()) do 
    for _, fixture in pairs(body:getFixtureList()) do
      local userdata = fixture:getUserData()
      if userdata and instanceOf(Junk, userdata) and userdata.planet == self then
        self.junk = self.junk + 1
      end
    end
  end
end
local scoreFont = love.graphics.newFont(36)
function Planet:draw()
  local scale = self.radius / self.image:getWidth() * 2
  love.graphics.setColor(self.color)
  love.graphics.draw(self.image,self.x,self.y,self.body:getAngle(),scale,nil,self.image:getWidth()/2,self.image:getHeight()/2)
  love.graphics.setColor(1,1,1)
  love.graphics.circle('fill', self.x, self.y, 24)
  love.graphics.setColor(0,0,0)
  love.graphics.printf(self.junk or '',scoreFont, self.x-50, self.y-scoreFont:getHeight()/2,100,'center')
  love.graphics.setColor(1,1,1)
end
function Planet:getNearest(aClass,x,y)
  local closestObject
  local clostestDist2

  for _, contact in ipairs(self.body:getContactList()) do
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
function KeyController:initialize(keyLeft, keyRight, keyShoot, align)
  self.keyLeft = keyLeft
  self.keyRight = keyRight
  self.keyShoot = keyShoot
  self.align = align or 'left'
end
function KeyController:update(dt)
  if love.keyboard.isScancodeDown(self.keyLeft) then
    self.player:move(-1)
  elseif love.keyboard.isScancodeDown(self.keyRight) then
    self.player:move(1)
  else
    self.player:move(0)
  end

  if love.keyboard.isScancodeDown(self.keyShoot) and self.lastShootKey == false then
    self.player:shoot()
  end
  self.lastShootKey = love.keyboard.isScancodeDown(self.keyShoot)
end
local keyFont = love.graphics.newFont(64)
local leftIcon = love.graphics.newImage('assets/anticlockwise-rotation.png')
local shootIcon = love.graphics.newImage('assets/thrust.png')
function KeyController:draw()
  local c = self.player.planet.color
  local x = self.align == 'left' and 0 or love.graphics.getWidth()-64
  love.graphics.setColor(c)
  love.graphics.draw(leftIcon,x,love.graphics.getHeight()-64*2)
  love.graphics.printf(string.upper(love.keyboard.getKeyFromScancode(self.keyLeft)), keyFont, 64,love.graphics.getHeight()-64*2,love.graphics.getWidth()-128,self.align)
  love.graphics.draw(leftIcon,x+64,love.graphics.getHeight()-64*3.5,0,-1,1)
  love.graphics.printf(string.upper(love.keyboard.getKeyFromScancode(self.keyRight)), keyFont, 64,love.graphics.getHeight()-64*3.5,love.graphics.getWidth()-128,self.align)
  if not self.player.junk then
    love.graphics.setColor(c[1],c[2],c[3],0.5)
  end
  love.graphics.draw(shootIcon,x,love.graphics.getHeight()-64*5)
  love.graphics.printf(string.upper(love.keyboard.getKeyFromScancode(self.keyShoot)), keyFont, 64,love.graphics.getHeight()-64*5,love.graphics.getWidth()-128,self.align)
  love.graphics.setColor(1,1,1)
end

AIController = class('AIController')
AIController.idletime = 1
function AIController:addEnemy(enemy)
  self.enemylist = self.enemylist or {}
  table.insert(self.enemylist, enemy)
end
function AIController:update(dt)
  self.idle = (self.idle or 0) - dt
  if self.idle > 0 then
    self.player:move(0)
    return
  end

  local player = self.player
  if player.junk then
    for _,enemy in ipairs(self.enemylist) do
      local ex,ey = enemy.body:getPosition()
      local vx,vy = vec.normalize(self.player.body:getLinearVelocity())
      local dx,dy = vec.normalize(vec.sub(ex,ey,self.player.body:getPosition()))
      if vec.dot(vx,vy,dx,dy) > math.cos(5/180*math.pi) then
        self.player:shoot()
        --self.idle = self.idletime
      elseif player.dir == 0 then
        player:move(1)
      end
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
  --[[
  local junk,dir = self.player.planet:getNearest(Junk,self.player.body:getPosition())
  if junk then
    love.graphics.line(self.player.body:getX(), self.player.body:getY(), junk.body:getPosition())
  end
  ]]--
end

Player = class('Player')
Player.radius = 15
Player.speed = 300
Player.image = love.graphics.newImage('assets/sad-crab.png')
function Player:initialize(world,planet,controller)
  local x,y = vec.add(planet.x, planet.y,vec.randomDirection(self.radius+planet.radius))
  self.body = love.physics.newBody(world,x,y, 'dynamic')
  self.shape = love.physics.newCircleShape(self.radius)
  self.fixture = love.physics.newFixture(self.body, self.shape, 100)
  self.body:setMass(2)
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

  for _,contact in ipairs(self.body:getContactList()) do
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
  love.graphics.setColor(self.planet.color)
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
Junk.restitution = 0
Junk.shapetype = 'rectangle'
Junk.image = love.graphics.newImage('assets/wooden-crate.png')
function Junk:initialize(world,x,y,vx,vy)
  self.body = love.physics.newBody(world, x,y, 'dynamic')
  if self.shapetype == 'rectangle' then
    self.shape = love.physics.newRectangleShape(self.radius*1.5,self.radius*1.5)
  else
    self.shape = love.physics.newCircleShape(self.radius)
  end
  self.fixture = love.physics.newFixture(self.body, self.shape,100)
  self.body:setLinearVelocity(vx or 0,vy or 0)
  self.body:setMass(0.5)
  self.body:setFixedRotation(false)
  self.fixture:setUserData(self)
  self.fixture:setFriction(10)
  self.body:setAngularDamping(10)
  self.fixture:setRestitution(self.restitution)
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
  for _,contact in ipairs(self.body:getContactList()) do
    --if contact:isTouching() then
      local planet = getOtherFixture(self.fixture,contact):getUserData()
      if planet and instanceOf(Planet, planet) then
        self.planet = planet
        self.color = planet.color
        break
      end
    --end
  end

  local vx,vy = self.body:getLinearVelocity()
  self.body:setLinearVelocity(vec.trim(1000,vx,vy))
end
function Junk:draw()
  local scale = self.radius / self.image:getWidth() * 2
  love.graphics.setColor(self.color)
  love.graphics.draw(self.image,self.body:getX(),self.body:getY(),self.body:getAngle(),scale,nil,self.image:getWidth()/2,self.image:getHeight()/2)
end

JunkBall = class("JunkBall", Junk)
JunkBall.shapetype = 'circle'
JunkBall.restitution = 0.5
JunkBall.image = love.graphics.newImage('assets/volleyball-ball.png')
