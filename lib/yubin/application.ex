defmodule Yubin.Application do
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    :ok = Yubin.Table.load()
    Supervisor.start_link([], strategy: :one_for_one, name: Yubin.Supervisor)
  end

  @impl Application
  def stop(_state) do
    Yubin.Table.unload()
    :ok
  end
end
