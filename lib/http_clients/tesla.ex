defmodule ExTract.HttpClients.Tesla do
  @behaviour ExTract.HttpClient
  use Tesla

  plug Tesla.Middleware.JSON

  @impl true
  def request(method, url, headers) do
    request(method: method, url: url, headers: headers)
  end
end
