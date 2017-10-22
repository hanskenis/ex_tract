defmodule ExTractTest do
  use ExUnit.Case, async: true
  doctest ExTract

  import Mox

  defmodule TestClient do
    use ExTract, file: "test/test.json"
  end

  setup :verify_on_exit!

  setup do
    expect(ExTract.HttpClientMock, :request, &request/3)
    Application.put_env(:ex_tract, :http_client, ExTract.HttpClientMock)
  end

  test "list_tests" do
    assert :ok == TestClient.list_tests()
    assert_received {:request, :get, "http://api.example.com/v1/tests?", []}
  end

  test "post_tests" do
    assert :ok == TestClient.post_tests()
    assert_received {:request, :post, "http://api.example.com/v1/tests?", []}
  end

  test "list_issues/2" do
    assert :ok == TestClient.list_issues("1234", "finished")
    assert_received {:request, :get, "http://api.example.com/v1/issues?status=finished", [{"apikey", "1234"}]}
  end

  test "list_issues/3" do
    assert :ok == TestClient.list_issues("1234", "delivered", tag: "bug", priority: "high")
    assert_received {:request, :get, "http://api.example.com/v1/issues?status=delivered&tag=bug&priority=high", [{"apikey", "1234"}]}
  end

  defp request(method, url, headers) do
    send self(), {:request, method, url, headers}
    :ok
  end
end
