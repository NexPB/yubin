defmodule Yubin.Table do
  @moduledoc false

  use GenServer

  @table __MODULE__
  @format 2

  def start_link(_arg), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  @spec rows(String.t()) :: [tuple()]
  def rows(code) do
    case :ets.lookup(@table, code) do
      [{^code, rows}] -> :erlang.binary_to_term(rows)
      [] -> []
    end
  end

  @spec data_version() :: Date.t()
  def data_version, do: :ets.lookup_element(@table, :data_version, 2)

  @impl GenServer
  def init(nil) do
    path = Application.app_dir(:yubin, "priv/postal.etf")
    %{format: @format, data_version: version, entries: entries} = path |> File.read!() |> :erlang.binary_to_term()

    :ets.new(@table, [:set, :protected, :named_table, read_concurrency: true])
    :ets.insert(@table, [{:data_version, version} | entries])

    # Hibernating drops the decoded file from this process's heap.
    {:ok, nil, :hibernate}
  end
end
