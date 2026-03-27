defmodule Ip2Asn.Updater do
  @moduledoc """
  GenServer that downloads the ip2asn dataset from iptoasn.com and keeps it
  fresh with a daily refresh.

  On startup the updater checks whether a locally cached copy is younger than
  24 hours. If so it loads from disk; otherwise it downloads a fresh copy,
  saves it to disk, and loads it into `Ip2Asn.Store`.

  Auto-updating can be disabled by setting `config :ip2asn, auto_update: false`
  (used in tests to avoid network calls).
  """

  use GenServer
  require Logger

  @dataset_url "https://iptoasn.com/data/ip2asn-combined.tsv.gz"
  @update_interval :timer.hours(24)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    if Application.get_env(:ip2asn, :auto_update, true) do
      send(self(), :update)
    end

    {:ok, %{}}
  end

  @impl true
  def handle_info(:update, state) do
    do_update()
    schedule_next()
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Internal helpers
  # ---------------------------------------------------------------------------

  defp local_path do
    dir = Application.app_dir(:ip2asn, "priv")
    Path.join(dir, "ip2asn-combined.tsv")
  end

  defp dataset_fresh? do
    path = local_path()

    case File.stat(path, time: :posix) do
      {:ok, %{mtime: mtime}} ->
        System.os_time(:second) - mtime < 86_400

      _ ->
        false
    end
  end

  defp do_update do
    if dataset_fresh?() do
      Logger.info("[Ip2Asn] Dataset is fresh – loading from disk")
      load_from_disk()
    else
      Logger.info("[Ip2Asn] Downloading dataset from #{@dataset_url}")
      download_and_load()
    end
  end

  defp load_from_disk do
    case File.read(local_path()) do
      {:ok, data} ->
        load_into_store(data)

      {:error, reason} ->
        Logger.warning("[Ip2Asn] Could not read local dataset (#{inspect(reason)}), downloading…")
        download_and_load()
    end
  end

  defp download_and_load do
    case download() do
      {:ok, data} ->
        persist(data)
        load_into_store(data)

      {:error, reason} ->
        Logger.error("[Ip2Asn] Failed to download dataset: #{inspect(reason)}")
    end
  end

  defp download do
    case Req.get(@dataset_url, decode_body: false) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, decompress(body)}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Detects gzip by magic bytes so we handle both pre-decompressed and raw responses.
  defp decompress(<<0x1F, 0x8B, _::binary>> = data), do: :zlib.gunzip(data)
  defp decompress(data), do: data

  defp persist(data) do
    path = local_path()
    File.mkdir_p!(Path.dirname(path))

    case File.write(path, data) do
      :ok -> Logger.info("[Ip2Asn] Dataset saved to #{path}")
      {:error, reason} -> Logger.warning("[Ip2Asn] Could not save dataset: #{inspect(reason)}")
    end
  end

  defp load_into_store(data) do
    Logger.info("[Ip2Asn] Loading dataset (#{byte_size(data)} bytes)…")

    case Ip2Asn.Store.update(data) do
      :ok -> Logger.info("[Ip2Asn] Dataset loaded successfully")
      {:error, reason} -> Logger.error("[Ip2Asn] Failed to load dataset: #{inspect(reason)}")
    end
  end

  defp schedule_next do
    Process.send_after(self(), :update, @update_interval)
  end
end
