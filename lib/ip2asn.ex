defmodule Ip2Asn do
  @moduledoc """
  Supervisor and public API for IP-to-ASN lookups.

  `Ip2Asn` supervises three children:
    - `Ip2Asn.Store` – holds the in-memory NIF reference to the ASN dataset.
    - `Ip2Asn.Updater` – downloads the dataset from iptoasn.com on startup and
      refreshes it every 24 hours.
    - A `Cachex` cache that memoises successful lookup results.

  ## Examples

      iex> Ip2Asn.Store.update("31.13.64.0\t31.13.127.255\t32934\tUS\tFACEBOOK-AS")
      :ok
      iex> {:ok, info} = Ip2Asn.lookup("31.13.100.100")
      iex> info.asn
      32934

  """

  use Supervisor

  @cache_name :ip2asn_cache

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      {Cachex, name: @cache_name},
      Ip2Asn.Store,
      Ip2Asn.Updater
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Looks up ASN information for the given IP address.

  Results are cached. Returns `{:error, :not_loaded}` while the dataset is
  still being fetched on startup.
  """
  @spec lookup(binary()) :: {:ok, Ip2Asn.Store.asn_info()} | {:error, term()}
  def lookup(ip) do
    case Cachex.get(@cache_name, ip) do
      {:ok, nil} ->
        result = Ip2Asn.Store.lookup(ip)
        if match?({:ok, _}, result), do: Cachex.put(@cache_name, ip, result)
        result

      {:ok, cached} ->
        cached

      {:error, _} ->
        Ip2Asn.Store.lookup(ip)
    end
  end
end
