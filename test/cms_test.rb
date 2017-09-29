ENV["RACK_ENV"] = "test"

# require 'pp'

require "fileutils"

require "minitest/autorun"
require "rack/test"

require_relative "../cms"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end
  
  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => { username: "admin" } }
  end

  def redirect_path
    # this is probably not the best way to do this. Has side effect of going to the path
    get last_response["Location"]
    last_request.env["PATH_INFO"]
  end

  def test_index
    create_document "about.md"
    create_document "changes.txt"

    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
  end

  def test_viewing_text_document
    create_document "about.txt", "Line 1\nLine 2"

    get "/about.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "Line 1\nLine 2"
  end

  def test_viewing_markdown_document
    create_document "lincoln.md", "# Gettysburg Address\nFour score and seven . . ."

    get "/lincoln.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Gettysburg Address</h1>"
  end

  def test_document_not_found
    get "/notafile.ext"

    assert_equal 302, last_response.status
    assert_equal "notafile.ext does not exist.", session[:message]
  end

  def test_index_page_has_edit_links_for_documents
    create_document "james.txt"
    create_document "sasha.txt"

    get "/"

    assert_includes last_response.body, "<a href=\"/james.txt/edit\">edit</a>"
    assert_includes last_response.body, "<a href=\"/sasha.txt/edit\">edit</a>"
  end

  def test_editing_document
    create_document "changes.txt"

    get "/changes.txt/edit", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_editing_document_signed_out
    create_document "changes.txt"

    get "/changes.txt/edit"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]

    assert_equal "/", redirect_path
  end

  def test_updating_document
    create_document "about.txt", "Original text"

    post '/about.txt', { content: "Updated text" }, admin_session

    assert_equal 302, last_response.status
    assert_equal "about.txt has been updated.", session[:message]

    get "/about.txt"
    assert_equal 200, last_response.status
    assert_equal "Updated text", last_response.body
  end

  def test_updating_document_signed_out
    create_document "about.txt", "Original text"

    post '/about.txt', content: "Updated text"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]

    assert_equal "/", redirect_path
  end

  def test_index_page_has_new_document_link
    get "/"

    assert_includes last_response.body, %q(<a href="/new">New Document</a>)
  end

  def test_view_new_document_form
    get "/new", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(<input)
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_viewing_new_document_signed_out
    get "/new"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]

    assert_equal "/", redirect_path
  end

  def test_create_new_document
    post "/create", { filename: "story.md" }, admin_session

    assert_equal 302, last_response.status
    assert_includes "story.md has been created.", session[:message]

    get "/"
    assert_includes last_response.body, "story.md"

    get "/story.md"
    assert_equal 200, last_response.status
  end

  def test_create_new_document_signed_out
    post "/create", filename: "story.md"

    assert_equal 302, last_response.status
    assert_includes "You must be signed in to do that.", session[:message]

    assert_equal "/", redirect_path
  end

  def test_create_new_document_without_filename
    post "/create", { filename: "   " }, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required"
  end

  def test_create_new_document_with_invalid_extname
    post "/create", { filename: "testing" }, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid file type"
  end

  def test_delete_document
    create_document "temp.txt"
    
    post "/temp.txt/delete", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "temp.txt has been deleted.", session[:message]

    get "/"
    refute_includes last_response.body, %q(href="/temp.txt")
  end

  def test_delete_document_signed_out
    create_document "temp.txt"
    
    post "/temp.txt/delete"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]

    assert_equal "/", redirect_path
  end

  def test_sign_in_form
    get "/"

    assert_includes last_response.body, "Sign In"

    get "/users/signin"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, "Username"
    assert_includes last_response.body, "Password"
    assert_includes last_response.body, %q(<button class="submit")
  end

  def test_signing_in_with_valid_credentials
    post "/users/signin", username: "admin", password: "secret"

    assert_equal 302, last_response.status

    assert_equal "Welcome!", session[:message]
    assert_equal "admin", session[:username]

    get last_response["Location"]

    assert_includes last_response.body, "Signed in as admin"
    assert_includes last_response.body, "Sign Out"
  end

  def test_signing_in_with_invalid_credentials
    post "/users/signin", username: "admin", password: "wrong_password"

    assert_equal 422, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, "Invalid credentials"
    assert_includes last_response.body, "admin"
  end

  def test_signing_out
    # sign in
    get "/", {}, { "rack.session" => { username: "admin" } }
    assert_includes last_response.body, "Signed in as admin"

    post "/users/signout"
    assert_equal 302, last_response.status

    assert_equal "You have been signed out.", session[:message]
    assert_nil session[:username]

    get last_response["Location"]

    assert_includes last_response.body, "Sign In"
  end
end
