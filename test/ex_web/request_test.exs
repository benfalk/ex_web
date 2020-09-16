defmodule ExWebTest.RequestTest do
  use ExUnit.Case
  alias ExWeb.Request

  describe "load/2" do
    setup %{buffer: buffer} do
      {:ok, response: Request.load(Request.new(), buffer)}
    end

    @tag buffer: "GET /foo/bar"
    test "not getting a full request line", %{response: response} do
      assert {:ok, %Request{}, "GET /foo/bar"} = response
    end

    @tag buffer: "GET / HTTP/1.1\r\n\r\n"
    test "minimum valid request buffer", %{response: response} do
      assert {:ok, req, ""} = response
      assert req.loaded?
      assert req.method == :get
      assert req.route == "/"
      assert req.query_params == %{}
      assert req.headers == %{}
      assert req.body == ""
      assert req.version == "HTTP/1.1"
    end

    @tag buffer: """
         GET /foo/bar?biz=buz&baz=bum HTTP/1.1\r
         Host: localhost\r
         Accept: */*\r
         \r
         """
    test "headers and query_params", %{response: response} do
      assert {:ok, req, ""} = response
      assert req.loaded?
      assert req.method == :get
      assert req.route == "/foo/bar"
      assert req.query_params == %{"biz" => "buz", "baz" => "bum"}
      assert req.headers == %{"host" => "localhost", "accept" => "*/*"}
      assert req.body == ""
      assert req.version == "HTTP/1.1"
    end
  end
end
