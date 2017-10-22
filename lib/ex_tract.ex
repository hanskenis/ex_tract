defmodule ExTract do
  defmacro __using__(opts) do
    schema = File.read!("#{(opts[:file])}") |> parse_json()
    paths = Map.get(schema, "paths")
    scheme = Map.get(schema, "schemes") |> List.first()
    host = Map.get(schema, "host")
    base_path = Map.get(schema, "basePath")

    quote do
      unquote(generate_paths(scheme, host, base_path, paths))

      def http_client() do
        Application.get_env(:ex_tract, :http_client, ExTract.HttpClients.Tesla)
      end
    end
  end

  defp generate_paths(scheme, host, base_path, paths) do
    for path <- paths do
      generate_path(scheme, host, base_path, path)
    end
  end

  defp generate_path(scheme, host, base_path, {path, operations}) do
    for operation <- operations do
      generate_operation(scheme, host, base_path, path, operation)
    end
  end

  defp generate_operation(scheme, host, base_path, path, {method, operation}) do
    operation_id = operation
                   |> Map.get("operationId", default_name(method, path))
                   |> Macro.underscore()
                   |> String.to_atom
    url = url(scheme, host, base_path, path)
    parameters = Map.get(operation, "parameters") || []
    method = String.to_atom(method)
    generate_function(operation_id, url, method, parameters)
  end

  defp generate_function(name, url, method, parameters) do
    arguments = parameters
                |> filter_parameters("required")
                |> parameter_names()
                |> Enum.map(&String.to_atom/1)
                |> Enum.map(&(Macro.var(&1, __MODULE__)))
    optional_arguments? = parameters
                          |> filter_parameters("required", false)
                          |> Enum.any?()
    if optional_arguments? do
      quote do
        def unquote(name)(unquote_splicing(arguments), opts \\ []) do
          unquote(generate_function_body(method, url, parameters))
        end
      end
      else
      quote do
        def unquote(name)(unquote_splicing(arguments)) do
          unquote(generate_function_body(method, url, parameters))
        end
      end
    end
  end

  defp generate_function_body(method, url, parameters) do
    headers = parameters
              |> filter_parameters("required", true)
              |> filter_parameters("in", "header")
              |> parameter_names()
              |> Enum.map(fn(name) -> {name, Macro.var(String.to_atom(name), __MODULE__)} end)
    query_params = parameters
                   |> filter_parameters("required")
                   |> filter_parameters("in", "query")
                   |> parameter_names()
                   |> Enum.map(&String.to_atom/1)
                   |> Enum.map(fn(name) -> {name, Macro.var(name, __MODULE__)} end)
    optional_arguments? = parameters
                          |> filter_parameters("required", false)
                          |> Enum.any?()
    quote do
      query_params = unquote(query_params)
      unquote(if optional_arguments?, do: generate_optional_arguments(parameters))
      IO.inspect(query_params)
      query = URI.encode_query(query_params)
      url = unquote(url)
            |> URI.parse()
            |> Map.put(:query, query)
            |> URI.to_string()

      http_client().request(unquote(method), url, [unquote_splicing(headers)])
    end
  end

  defp generate_optional_arguments(parameters) do
    quote do 
      unquote(optional_query_parameters(parameters))
    end
  end

  defp optional_query_parameters(parameters) do
    query_params = parameters
                   |> filter_parameters("required", false)
                   |> filter_parameters("in", "query")
                   |> parameter_names()
                   |> Enum.map(&String.to_atom/1)
    quote do
      unquote_splicing(temp(query_params))
    end
  end

  defp temp(query_params) do
    for query_param <- query_params do
      quote do
        query_params = if value = Keyword.get(opts, unquote(query_param)) do
          query_params ++ [{unquote(query_param), value}]
        else
          query_params
        end
      end
    end
  end

  defp filter_parameters(parameters, key, value \\ true) do
    Enum.filter(parameters, fn(parameter) -> Map.get(parameter, key) == value end)
  end

  defp parameter_names(parameters) do
    Enum.map(parameters, fn(parameter) -> Map.get(parameter, "name") end)
  end

  defp default_name(method, "/" <> path), do: method <> "_" <> path

  defp url(scheme, host, base_path, path) do
    URI.to_string(%URI{scheme: scheme, host: host, path: base_path <> path})
  end

  def parse_json(json) do
    json
    |> Poison.decode!()
  end
end
