ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"

require_relative "../cms"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.mkdir_p(data_path)
  end

  def app
    Sinatra::Application
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

    get last_response["Location"]

    assert_equal 200, last_response.status
    assert_includes last_response.body, "notafile.ext does not exist"
  end

  def test_index_page_has_edit_links_for_documents
    create_document "james.txt"
    create_document "sasha.txt"

    get "/"

    assert_includes last_response.body, "<a href=\"/james.txt/edit\">Edit</a>"
    assert_includes last_response.body, "<a href=\"/sasha.txt/edit\">Edit</a>"
  end

  def test_editing_a_document
    create_document "changes.txt"

    get "/changes.txt/edit"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_updating_document
    create_document "about.txt", "Original text"

    post '/about.txt', content: "Updated text"

    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_includes last_response.body, "about.txt has been updated"

    get "/about.txt"
    assert_equal 200, last_response.status
    assert_equal "Updated text", last_response.body
  end
end
