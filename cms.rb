require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"

get "/" do
  root = File.expand_path("..", __FILE__)

  @files = Dir.glob(root + "/data/*").map do |path|
    File.basename(path)
  end
  erb :index
end
