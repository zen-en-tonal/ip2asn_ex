defmodule Ip2Asn.Store do
  @moduledoc """
  GenServer that holds the in-memory NIF reference to the ip2asn dataset.

  The reference is updated by `Ip2Asn.Updater`. Lookups call into the Rust
  NIF from the caller's process; the GenServer only provides the reference.
  """

  use GenServer

  @type asn_info :: %{
          network: binary(),
          asn: non_neg_integer(),
          country_code: binary(),
          organization: binary()
        }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Looks up ASN information for `ip`. Returns `{:error, :not_loaded}` before the first dataset is loaded."
  @spec lookup(binary()) :: {:ok, asn_info()} | {:error, term()}
  def lookup(ip) do
    case GenServer.call(__MODULE__, :get_ref) do
      nil -> {:error, :not_loaded}
      ref -> normalise(Ip2Asn.Nif.lookup(ref, ip))
    end
  end

  @doc "Replaces the dataset with the TSV binary `data`. Returns `:ok` or `{:error, reason}`."
  @spec update(binary()) :: :ok | {:error, term()}
  def update(data) do
    GenServer.call(__MODULE__, {:update, data}, :infinity)
  end

  @impl true
  def init(_opts), do: {:ok, nil}

  @impl true
  def handle_call(:get_ref, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:update, data}, _from, state) do
    case Ip2Asn.Nif.build(data) do
      {:ok, ref} -> {:reply, :ok, ref}
      other -> {:reply, {:error, other}, state}
    end
  end

  # The Rust NIF returns {:ok, info} on success and a bare atom on failure.
  defp normalise({:ok, _} = ok), do: ok
  defp normalise(reason), do: {:error, reason}
end
