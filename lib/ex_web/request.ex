defmodule ExWeb.Request do
  @moduledoc """
  The responsibility of this module is to load a binary buffer
  stream into a structured representation of an http request.
  """

  alias __MODULE__, as: Request

  @type method :: :unset | :get | :post | :put | :delete
  @type route :: :unset | binary()
  @type version :: :unset | binary()
  @type headers :: :unset | %{optional(binary()) => binary()}
  @type body_length :: :unset | non_neg_integer()
  @type query_params() :: :unset | %{optional(binary()) => binary()}
  @type body :: :unset | binary()
  @type t :: %Request{
          method: method(),
          route: route(),
          version: version(),
          headers: headers(),
          query_params: query_params(),
          body: body(),
          loaded?: boolean()
        }

  defstruct method: :unset,
            route: :unset,
            version: :unset,
            headers: :unset,
            body_length: :unset,
            query_params: :unset,
            body: :unset,
            loaded?: false

  @supported_methods [
    get: "GET",
    post: "POST",
    put: "PUT",
    delete: "DELETE"
  ]

  @spec new() :: Request.t()
  def new, do: %Request{}

  @doc """
  This is the workhorse of reading a binary stream for an http request and storing
  it's decoded process as the Request struct fills with data.  As you load the
  request with parts of a buffer it will return a request loaded with as much information
  as could be decoded by the the supplied buffer and any remainding buffer which could
  not yet be used.
  """
  @spec load(Request.t(), binary()) :: {:ok, Request.t(), binary()} | {:error, atom()}
  def load(%Request{method: :unset} = req, buffer) do
    case :binary.split(buffer, "\r\n") do
      [buffer] ->
        {:ok, req, buffer}

      [request_line, remainder] ->
        with {:ok, updated_req} <- decode_request_line(req, request_line) do
          load(updated_req, remainder)
        end
    end
  end

  def load(%Request{headers: :unset} = req, <<"\r\n", buffer::binary>>) do
    load(%{req | headers: %{}}, buffer)
  end

  def load(%Request{headers: :unset} = req, buffer) do
    case :binary.split(buffer, "\r\n\r\n") do
      [buffer] ->
        {:ok, req, buffer}

      [headers_str, remainder] ->
        with {:ok, headers} <- decode_headers(headers_str),
             {:ok, body_length} <- decode_body_length(headers) do
          load(%{req | headers: headers, body_length: body_length}, remainder)
        end
    end
  end

  def load(%Request{body: :unset, body_length: :unset} = req, buffer) do
    {:ok, %{req | body: "", loaded?: true}, buffer}
  end

  def load(%Request{body: :unset, body_length: length} = req, buffer) do
    # TODO : There is some slowness here with bigger files; maybe
    # I need to chunk build up the body instead of waiting for the
    # buffer to get big enough?
    if byte_size(buffer) >= length do
      <<body::bytes-size(length), rem::binary>> = buffer
      {:ok, %{req | loaded?: true, body: body}, rem}
    else
      {:ok, req, buffer}
    end
  end

  ## Private Functions

  defp decode_request_line(req, request_line) do
    case :binary.split(request_line, " ", [:global]) do
      [possible_method, uri, version] ->
        with {:ok, method} <- decode_method(possible_method),
             {:ok, path, params} <- decode_uri(uri) do
          {:ok, %{req | method: method, route: path, version: version, query_params: params}}
        end

      _ ->
        {:error, :malformed_request_line}
    end
  end

  defp decode_uri(uri_str) do
    case :binary.split(uri_str, "?") do
      [path_only] ->
        {:ok, URI.decode(path_only), %{}}

      [path, params] ->
        {:ok, URI.decode(path), URI.decode_query(params)}
    end
  end

  defp decode_headers(headers_str) do
    key_value_strings = :binary.split(headers_str, "\r\n", [:global])

    with {:ok, pairs} <- decode_header_strings(key_value_strings, []) do
      {:ok, Map.new(pairs)}
    end
  end

  defp decode_header_strings([], pairs), do: {:ok, pairs}

  defp decode_header_strings([str | tail], pairs) do
    case :binary.split(str, ":") do
      [key, val] ->
        decode_header_strings(tail, [{String.downcase(key), String.trim(val)} | pairs])

      _ ->
        {:error, :malformed_request_header}
    end
  end

  defp decode_body_length(%{"content-length" => possible_length}) do
    case Integer.parse(possible_length) do
      {length, ""} -> {:ok, length}
      _ -> {:error, :bad_content_length}
    end
  end

  defp decode_body_length(_), do: {:ok, :unset}

  for {atom, bin} <- @supported_methods do
    defp decode_method(unquote(bin)), do: {:ok, unquote(atom)}
  end

  defp decode_method(_), do: {:error, :unsupported_method}
end
