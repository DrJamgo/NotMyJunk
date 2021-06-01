--
-- Copyright DrJamgo@hotmail.com 2021
--
love.filesystem.setRequirePath("?.lua;?/init.lua;lua/?.lua;lua/?/init.lua")

if arg[#arg] == "-debug" then
  if pcall(require, "lldebugger") then require("lldebugger").start() end -- << vscode debugger
  if pcall(require, "mobdebug") then require("mobdebug").start() end -- << zerobrain debugger
end

Gamestate = require "hump.gamestate"
require 'middleclass'
require 'objects'
require 'menu'

local bgmusic = love.audio.newSource('assets/OutThere.ogg', 'static')
bgmusic:setLooping(true)
love.audio.play(bgmusic)

function love.load()
  Gamestate.registerEvents()
  Gamestate.switch(Menu())
end

function love.update(dt)
 
end

function love.draw()

end

function love.mousepressed(x, y, button, istouch, presses)

end

function love.keypressed(key)
end
