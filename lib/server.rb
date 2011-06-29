#!/usr/bin/env ruby

require "rubygems"
require "bundler/setup"
require 'eventmachine'
require 'em-websocket'
require 'evma_httpserver'
require 'ruby-debug'
require 'json'


class Screen
  @@ws = nil

  def self.init(ws)
    @@ws = ws
  end

  def self.send(data)
    @@ws.send(data)
  end

  def self.connected?
    !!@@ws
  end
end

class Player
  COLORS = %w{black red green blue yellow orange purple cyan magenta navajoWhite beige aliceBlue aquamarine bisque coral darkGreen darkBlue}
  @@all = []
  @@count = 0

  attr_accessor :name, :uid, :ws, :top, :left

  def initialize(uid)
    @uid = uid
    @ws = ws
    @top = 10
    @left = 10 + (@@count * 10) 
    @@count += 1
    @color = COLORS[@@count]
    @name = "#{uid}"
    @@all << self
    Screen.send({ :action => :player_info, :params => { :uid => @uid, :name => @name, :color => @color} }.to_json) if Screen.connected?
    # Player.all.each {|p| p.ws.send({ :action => :send_state, :params => Player.state}.to_json)}
  end

  def self.state
    Player.all.collect{|p| { :uid => p.uid, :name => p.name, :top => p.top, :left => p.left, :color => @color }}
  end

  def self.all
    @@all
  end

  def self.find_by_name(name)
    @@all.select {|p| p.name == name}.first
  end

  def self.find_by_uid(uid)
    @@all.select {|p| p.uid == uid}.first
  end

  def move(direction)
    case direction
    when 'right'
      @left += 20
    when 'left'
      @left -= 20
    when 'up'
      @top -= 20
    when 'down'
      @top += 20
    end
  end
end

# class InputHandler < EM::P::HeaderAndContentProtocol
#   def receive_request(headers, content)
#     p [:request, headers, content]
#     uid, action = $1, $2

#     player = Player.find_by_uid(uid) || Player.new(uid)
#     player.move(action)

#     Screen.send({:action => 'send_state', :params => Player.state}.to_json)
#   end
# end

class Handler < EventMachine::Connection
  include EventMachine::HttpServer

  def post_init
    super
    no_environment_strings
  end
 
  def process_http_request
    res = EventMachine::DelegatedHttpResponse.new( self )
    content = instance_variable_get '@http_post_content'
    p content
    content =~ /=([a-z0-9]+).*=([a-z0-9]+)/i
    uid, action = $1, $2

    player = Player.find_by_uid(uid) || Player.new(uid)
    player.move(action)

    Screen.send({:action => 'send_state', :params => Player.state}.to_json) if Screen.connected?

    res.headers["Access-Control-Allow-Origin"] = '*'
    res.status = 200
    res.content_type 'text/html'
    res.content = '<center><h1>Hi there</h1></center>'
    res.send_response
  end
end

EM.run do
  EM::WebSocket.start(:host => '0.0.0.0', :port => 8081) do |ws|
    ws.onopen do
      puts "Client connected."
      Screen.init(ws)
    end

    ws.onmessage do |data|
      puts 'Message received'
    end

    ws.onclose do
      puts "Client disconnected."
    end

    ws.onerror { |e| puts "err #{e.message}\n#{caller.join("\n")}" }
  end

  EventMachine.epoll
  EventMachine::start_server("0.0.0.0", 8080, Handler)

  # EventMachine::start_server("0.0.0.0", 8080, InputHandler)

  puts "Server is up! Open '#{File.expand_path('../../index.html', __FILE__)}' on your browser."
end