defmodule Ip2Asn.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    Ip2Asn.start_link([])
  end
end
