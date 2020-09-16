defmodule ExWeb.Response do
  alias __MODULE__, as: Response

  @type status :: :unset | pos_integer()
  @type body :: :unset | binary()
  @type headers :: :unset | %{optional(binary()) => binary()}
  @type t :: %Response{
          status: status(),
          body: body(),
          headers: headers()
        }

  defstruct status: :unset,
            body: :unset,
            headers: :unset

  @status_codes [
    {100, "Continue"},
    {101, "Switching Protocols"},
    {200, "OK"},
    {201, "Created"},
    {202, "Accepted"},
    {203, "Non-Authoritative Information"},
    {204, "No Content"},
    {205, "Reset Content"},
    {206, "Partial Content"},
    {300, "Multiple Choices"},
    {301, "Moved Permanently"},
    {302, "Found"},
    {303, "See Other"},
    {304, "Not Modified"},
    {305, "Use Proxy"},
    {307, "Temporary Redirect"},
    {400, "Bad Request"},
    {401, "Unauthorized"},
    {402, "Payment Required"},
    {403, "Forbidden"},
    {404, "Not Found"},
    {405, "Method Not Allowed"},
    {406, "Not Acceptable"},
    {407, "Proxy Authentication Required"},
    {408, "Request Time-out"},
    {409, "Conflict"},
    {410, "Gone"},
    {411, "Length Required"},
    {412, "Precondition Failed"},
    {413, "Request Entity Too Large"},
    {414, "Request-URI Too Large"},
    {415, "Unsupported Media Type"},
    {416, "Requested range not satisfiable"},
    {417, "Expectation Failed"},
    {500, "Internal Server Error"},
    {501, "Not Implemented"},
    {502, "Bad Gateway"},
    {503, "Service Unavailable"},
    {504, "Gateway Time-out"},
    {505, "HTTP Version not supported"}
  ]

  def new, do: %Response{}

  @spec to_binary(Response.t()) :: {:ok, binary()} | {:error, atom()}
  def to_binary(%Response{status: :unset}), do: {:error, :missing_status}

  def to_binary(%Response{} = resp) do
    with {:ok, resp_line} <- resp_line(resp.status),
         {:ok, headers} <- headers_str(resp),
         {:ok, body} <- body_str(resp) do
      {:ok, resp_line <> headers <> body}
    end
  end

  @spec set_status(Response.t(), status()) :: Response.t()
  def set_status(%Response{} = resp, status), do: %{resp | status: status}

  @spec add_header(Response.t(), binary(), binary()) :: Response.t()
  def add_header(%Response{headers: :unset} = resp, key, value) do
    add_header(%{resp | headers: %{}}, key, value)
  end

  def add_header(resp, key, value) do
    put_in(resp.headers[key], value)
  end

  @spec add_body(Response.t(), binary()) :: Response.t()
  def add_body(resp, body) do
    %{resp | body: body}
    |> add_header("Content-Length", byte_size(body))
  end

  ## Private Functions

  defp headers_str(%{headers: :unset}), do: {:ok, "\r\n"}

  defp headers_str(%{headers: headers}) do
    headers_str =
      headers
      |> Enum.map(fn {key, val} -> "#{key}: #{val}" end)
      |> Enum.join("\r\n")

    {:ok, headers_str <> "\r\n\r\n"}
  end

  def body_str(%{body: :unset}), do: {:ok, ""}
  def body_str(%{body: body}), do: {:ok, body}

  for {code, verbaige} <- @status_codes do
    def resp_line(unquote(code)), do: {:ok, unquote("HTTP/1.1 #{code} #{verbaige}\r\n")}
  end

  def resp_line(_), do: {:error, :unknown_http_code}
end
