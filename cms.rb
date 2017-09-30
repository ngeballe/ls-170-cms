require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "redcarpet"
require "yaml"
require "bcrypt"

configure do
  enable :sessions
  set :session_secret, 'captainmoonlight'
end

VALID_FILE_EXTENSIONS = %w[.txt .md]

# helpers do
# end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def create_document(name, content = "")
  File.open(File.join(data_path, name), "w") do |file|
    file.write(content)
  end
end

def load_file_content(path)
  content = File.read(path)
  case File.extname(path)
  when '.txt'
    headers["Content-Type"] = "text/plain"
    content
  when '.md'
    erb render_markdown(content)
  end
end

def load_filenames
  pattern = File.join(data_path, "*")
  Dir.glob(pattern).map do |path|
    File.basename(path)
  end
end

def invalid_extension?(filename)
  !VALID_FILE_EXTENSIONS.include? File.extname(filename)
end

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end

  YAML.load_file(credentials_path)
end

def valid_credentials?(username, password)
  credentials = load_user_credentials

  if credentials.key?(username)
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  else
    false
  end

  credentials.key?(username) &&
    BCrypt::Password.new(credentials[username]) == password
end

def signed_in_username
  session[:username]
end

def user_signed_in?
  session.key?(:username)
end

def require_signed_in_user
  unless user_signed_in?
    session[:message] = "You must be signed in to do that."
    redirect "/"
  end
end

def copy_number(filename)
  extname = File.extname(filename)
  return 0 unless filename =~ /copy( \d+)?#{extname}$/
  
  $1.nil? ? 1 : $1.to_i
end

def filename_stem(filename)
  # what's before 'copy x' in the name
  extname = File.extname(filename)
  filename.sub(/( copy( \d)*)?#{extname}/, '')
end

def next_integer(integers)
  # find missing integer in a series. If none are missing, take the max + 1

  raise ArgumentError unless integers.instance_of?(Array) &&
    integers.all? { |number| number.instance_of?(Integer) }

  integers.sort!
  integers_in_range = [*integers.min..integers.max]
  if integers_in_range == integers
    integers.max + 1
  else
    (integers_in_range - integers).first
  end
end

def next_copy_name(files, filename_being_copied)
  # extname = File.extname(filename_being_copied)
  filename_being_copied_stem = filename_stem(filename_being_copied)

  existing_copies = files.select do |file|
    filename_stem(file) == filename_being_copied_stem
  end

  existing_copy_numbers = existing_copies.map { |filename| copy_number(filename) }

  next_copy_number = next_integer(existing_copy_numbers)

  extname = File.extname(filename_being_copied)
  if next_copy_number == 1
    "#{filename_being_copied_stem} copy#{extname}"
  else
    "#{filename_being_copied_stem} copy #{next_copy_number}#{extname}"
  end
end

# Display index page with list of files
get "/" do
  @files = load_filenames

  erb :index
end

# Add a new document filename
get '/new' do
  require_signed_in_user

  erb :new
end

# Create a new document
post '/create' do
  require_signed_in_user

  filename = params[:filename].strip

  if filename.empty?
    session[:message] = "A name is required."
    status 422
    erb :new
  elsif invalid_extension?(filename)
    session[:message] = "Invalid file type"
    status 422
    erb :new
  else
    create_document(filename)
    session[:message] = "#{filename} has been created."
    redirect "/"
  end
end

# Sign-in form
get "/users/signin" do
  erb :signin
end

# Sign in
post "/users/signin" do
  username = params[:username]

  if valid_credentials?(username, params[:password])
    session[:username] = username
    session[:message] = "Welcome!"
    redirect '/'
  else
    session[:message] = "Invalid credentials!"
    status 422
    erb :signin
  end
end

# Sign out
post "/users/signout" do
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect "/"
end

# Display file
get "/:filename" do
  file_path = File.join(data_path, params[:filename])

  if File.exist?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

# Edit file content
get '/:filename/edit' do
  require_signed_in_user

  file_path = File.join(data_path, params[:filename])

  @filename = params[:filename]
  @content = File.read(file_path)

  erb :edit
end

# Update file content
post "/:filename" do
  require_signed_in_user

  file_path = File.join(data_path, params[:filename])

  File.write(file_path, params[:content])

  session[:message] = "#{params[:filename]} has been updated."
  redirect "/"
end

# Delete a file
post "/:filename/delete" do
  require_signed_in_user

  file_path = File.join(data_path, params[:filename])

  File.delete(file_path)

  session[:message] = "#{params[:filename]} has been deleted."
  redirect "/"
end

# Duplicate a file
post "/:filename/duplicate" do
  require_signed_in_user

  filename = params[:filename]
  files = load_filenames

  duplicate_name = next_copy_name(files, filename)
  
  file_path = File.join(data_path, filename)
  content = File.read(file_path)

  create_document(duplicate_name, content)

  session[:message] = "The file \"#{filename}\" has been duplicated as \"#{duplicate_name}\"."
  redirect "/"
end
