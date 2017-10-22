defmodule ExTract.HttpClient do
  @callback request(atom, binary, keyword) :: :ok
end
