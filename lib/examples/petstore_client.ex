defmodule PetstoreClient do
  use Tesla

  plug Tesla.Middleware.BaseUrl, "http://petstore.swagger.io/v2"
  plug Tesla.Middleware.JSON

  def list_pets() do
    get("/pet/findByStatus?status=available")
  end
end
