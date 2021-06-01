require 'middleclass'
require 'level'
local suit = require 'suit'
Menu = class('Menu')

local fontCaption = love.graphics.newFont(36)
local spaceImage = love.graphics.newImage('assets/space.jpg')


function Menu:initialize()

end

function Menu:update(dt)  
  suit.layout:reset(love.graphics.getWidth()/3,200)
  suit.layout:padding(20,20)

  self.inputMode = 'keyboard'
  if self.inputMode == nil then
    suit.Label('Select Input Mode:',suit.layout:row(love.graphics.getWidth()/3,30))
    if suit.Button('keyboard', suit.layout:row(love.graphics.getWidth()/3,50)).hit then
      self.inputMode = 'keyboard'
    end
    if suit.Button('touch' , suit.layout:row()).hit then
      self.inputMode = 'touch'
    end
  elseif self.numPlayers == nil then
    suit.Label('Select Player Count:',suit.layout:row(love.graphics.getWidth()/3,30))

    if suit.Button('0 Players', suit.layout:row(love.graphics.getWidth()/3,50)).hit then
      self.numPlayers = 0
    end
    if suit.Button('1 Player' , suit.layout:row()).hit then
      self.numPlayers = 1
    end
    if suit.Button('2 Players', suit.layout:row()).hit then
      self.numPlayers = 2
    end
    suit.layout:row()
    if suit.Button('GitHub Sources (and Credits)', suit.layout:row()).hit then
      love.system.openURL('https://github.com/DrJamgo/NotMyJunk')
    end
  else
    suit.Label('Select Level:',suit.layout:row(love.graphics.getWidth()/3,50))

    if suit.Button('Level 1 (ony one level for now)', suit.layout:row()).hit then
      Gamestate.switch(Level1(), self.numPlayers)
    end
    if suit.Button('<- back', suit.layout:row()).hit then
      self.numPlayers = nil
    end
  end
end

function Menu:draw()
  love.graphics.setColor(1,0.5,0.5)
  love.graphics.draw(spaceImage)
  love.graphics.setColor(1,1,1)
  love.graphics.printf(love.window.getTitle(),fontCaption,0,50,love.graphics.getWidth(),'center')

  suit.draw()
end

WinScreen = class('WinScreen')
function WinScreen:enter(from, winner)
  self.level = from
  self.winner = winner
  self.time = 0.2
end

function WinScreen:update(dt)
  self.time = self.time + dt

  suit.layout:reset(love.graphics.getWidth()/3,360)
  suit.layout:padding(20,20)

  if suit.Button('Play again!', suit.layout:row(love.graphics.getWidth()/3,50)).hit then
    Gamestate.switch(self.level.class(), self.level.numPlayers)
    suit:enterFrame()
  end
  if suit.Button('<-- Back to Menu', suit.layout:row(love.graphics.getWidth()/3,50)).hit then
    Gamestate.switch(Menu())
    suit:enterFrame()
  end
end

function WinScreen:draw()
  self.level:draw()
  love.graphics.setColor(0,0,0,math.min(0.8,self.time))
  love.graphics.rectangle('fill',0,0,love.graphics.getDimensions())
  love.graphics.setColor(self.winner.color)
  love.graphics.printf(self.winner.name .. " won !", fontCaption, 0, love.graphics.getHeight()/3,love.graphics.getWidth(),'center')
  love.graphics.setColor(1,1,1)

  suit.draw()
end