require "sinatra"
require "sinatra/json"
require "sinatra/base"
require "jwt"
require "sinatra/contrib"
require_relative "db"
require_relative "models/user"
require_relative "models/note"
require "sinatra/reloader"
register Sinatra::Namespace
session_secret = SecureRandom.hex(32)

configure do
  enable :sessions
  set :session_secret, session_secret
  set :views, File.join(__dir__, "views")
  set :public_folder, File.join(__dir__, "public")
  # set :erb, layout: :layout
end

JWT_SECRET = "eidfuhurhiudfbgtiehbidbfiutbeiubd"

# before do
#   content_type :json
# end

post "/login" do
  request_body = JSON.parse(request.body.read)

  username = request_body["username"]
  password = request_body["password"]

  user = User.authenticate(username, password)

  if user
    jwt_token = JWT.encode({ username: user.username }, JWT_SECRET, "HS256")
    { token: jwt_token }.to_json
  else
    status 401
    { error: "Invalid credentials" }.to_json
  end
end

post "/paste" do
  authorization_header = request.env["HTTP_AUTHORIZATION"]

  if authorization_header && authorization_header.start_with?("Bearer ")
    jwt_token = authorization_header.sub("Bearer ", "")
    payload = JWT.decode(jwt_token, JWT_SECRET, true, algorithm: "HS256").first

    username = payload["username"]
    user = User.find(username: username)

    if user
      request_body = JSON.parse(request.body.read)
      content = request_body["content"]

      note = user.add_note(content: content, created_at: Time.now)

      { message: "Paste saved successfully", note_id: note.id }.to_json
    else
      status 401
      { error: "Invalid token" }.to_json
    end
  else
    status 401
    { error: "Missing token" }.to_json
  end
end

get "/bin" do
  authorization_header = request.env["HTTP_AUTHORIZATION"]

  if authorization_header && authorization_header.start_with?("Bearer ")
    jwt_token = authorization_header.sub("Bearer ", "")
    payload = JWT.decode(jwt_token, JWT_SECRET, true, algorithm: "HS256").first

    username = payload["username"]
    user = User.find(username: username)

    if user
      notes = user.notes
      { content: notes.map(&:content) }.to_json
    else
      status 401
      { error: "Invalid token" }.to_json
    end
  else
    status 401
    { error: "Missing token" }.to_json
  end
end

post "/register" do
  request_body = JSON.parse(request.body.read)

  username = request_body["username"]
  password = request_body["password"]

  # Check if the username already exists
  if User.find(username: username)
    status 400
    { error: "Username already exists" }.to_json
  else
    user = User.new(username: username)
    user.password = password
    user.save

    { message: "User registered successfully" }.to_json
  end
end

put "/notes/:note_id" do
  authorization_header = request.env["HTTP_AUTHORIZATION"]

  if authorization_header && authorization_header.start_with?("Bearer ")
    jwt_token = authorization_header.sub("Bearer ", "")
    payload = JWT.decode(jwt_token, JWT_SECRET, true, algorithm: "HS256").first

    username = payload["username"]
    user = User.find(username: username)

    if user
      note = user.notes_dataset.first(id: params[:note_id])

      if note
        request_body = JSON.parse(request.body.read)
        new_content = request_body["content"]

        note.update(content: new_content)

        { message: "Note updated successfully" }.to_json
      else
        status 404
        { error: "Note not found" }.to_json
      end
    else
      status 401
      { error: "Invalid token" }.to_json
    end
  else
    status 401
    { error: "Missing token" }.to_json
  end
end

delete "/notes/:note_id" do
  authorization_header = request.env["HTTP_AUTHORIZATION"]

  if authorization_header && authorization_header.start_with?("Bearer ")
    jwt_token = authorization_header.sub("Bearer ", "")
    payload = JWT.decode(jwt_token, JWT_SECRET, true, algorithm: "HS256").first

    username = payload["username"]
    user = User.find(username: username)

    if user
      note = user.notes_dataset.first(id: params[:note_id])

      if note
        note.delete

        { message: "Note deleted successfully" }.to_json
      else
        status 404
        { error: "Note not found" }.to_json
      end
    else
      status 401
      { error: "Invalid token" }.to_json
    end
  else
    status 401
    { error: "Missing token" }.to_json
  end
end

get "/notes/:note_id" do
  authorization_header = request.env["HTTP_AUTHORIZATION"]

  if authorization_header && authorization_header.start_with?("Bearer ")
    jwt_token = authorization_header.sub("Bearer ", "")
    payload = JWT.decode(jwt_token, JWT_SECRET, true, algorithm: "HS256").first

    username = payload["username"]
    user = User.find(username: username)

    if user
      note = user.notes_dataset.first(id: params[:note_id])

      if note
        { content: note.content }.to_json
      else
        status 404
        { error: "Note not found" }.to_json
      end
    else
      status 401
      { error: "Invalid token" }.to_json
    end
  else
    status 401
    { error: "Missing token" }.to_json
  end
end

get "/notes" do
  authorization_header = request.env["HTTP_AUTHORIZATION"]

  if authorization_header && authorization_header.start_with?("Bearer ")
    jwt_token = authorization_header.sub("Bearer ", "")
    payload = JWT.decode(jwt_token, JWT_SECRET, true, algorithm: "HS256").first

    username = payload["username"]
    user = User.find(username: username)

    if user
      notes = user.notes_dataset.all

      { notes: notes.map { |note| { id: note.id, content: note.content } } }.to_json
    else
      status 401
      { error: "Invalid token" }.to_json
    end
  else
    status 401
    { error: "Missing token" }.to_json
  end
end

set :public_folder, Proc.new { File.join(root, "frontend") }

get "/" do
  erb :home
end
