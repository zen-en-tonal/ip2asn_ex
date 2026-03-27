# Ip2Asn

An Elixir library for fast IP-to-ASN (Autonomous System Number) lookups. Maps IPv4 and IPv6 addresses to their associated ASN, country code, and organization name.

Backed by a [Rust NIF](https://github.com/rusterlium/rustler) for high-performance in-memory lookups and [Cachex](https://github.com/whitfin/cachex) for result memoization. The dataset is sourced from [iptoasn.com](https://iptoasn.com/) and refreshed automatically every 24 hours.

## Features

- **Fast lookups** — binary search over an in-memory dataset compiled via a Rust NIF
- **Auto-updating** — downloads and refreshes the full IP-to-ASN dataset on startup and every 24 hours
- **Caching** — lookup results are memoized with Cachex
- **Plug middleware** — enriches Phoenix/Plug request connections with ASN info
- **IPv4 and IPv6 support**

## Installation

Add `:ip2asn` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ip2asn, "~> 0.1.0"},
    # Optional: only needed for Ip2Asn.Plug Phoenix middleware
    {:plug, ">= 1.0.0"}
  ]
end
```

> **Note:** This library includes a Rust NIF. You will need the Rust toolchain installed (`rustup`). The NIF is compiled automatically during `mix deps.compile`.

## Usage

### Basic lookup

```elixir
iex> Ip2Asn.lookup("31.13.100.100")
{:ok, %{
  network: "31.13.64.0/18",
  asn: 32934,
  country_code: "US",
  organization: "FACEBOOK-AS"
}}

iex> Ip2Asn.lookup("8.8.8.8")
{:ok, %{
  network: "8.8.8.0/24",
  asn: 15169,
  country_code: "US",
  organization: "GOOGLE"
}}

iex> Ip2Asn.lookup("192.0.2.1")
{:error, :not_found}
```

> The dataset is downloaded asynchronously on startup. While loading, `lookup/1` returns `{:error, :not_loaded}`.

### Plug middleware

Use `Ip2Asn.Plug` in a Phoenix pipeline to attach ASN information to every request:

```elixir
# router.ex
pipeline :api do
  plug :accepts, ["json"]
  plug Ip2Asn.Plug
end
```

The result is stored in `conn.assigns.asn_info`:

```elixir
def index(conn, _params) do
  case conn.assigns.asn_info do
    %{asn: asn, country_code: cc, organization: org} ->
      Logger.info("Request from ASN #{asn} (#{cc}) — #{org}")
    nil ->
      :ok
  end
  # ...
end
```

**Plug options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `:assign_as` | `atom` | `:asn_info` | Key used to store the result in `conn.assigns` |
| `:on_error` | `:ignore \| :halt` | `:ignore` | On lookup failure: assign `nil` and continue (`:ignore`), or respond `403` and halt (`:halt`) |

```elixir
# Custom key and halt on failure
plug Ip2Asn.Plug, assign_as: :client_asn, on_error: :halt
```

## Configuration

```elixir
# config/config.exs
config :ip2asn, auto_update: true
```

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `:auto_update` | `boolean` | `true` | Download dataset on startup and refresh every 24 hours |

Disable auto-update in tests to avoid network calls:

```elixir
# config/test.exs
config :ip2asn, auto_update: false
```

## Architecture

```
Ip2Asn (Supervisor, :one_for_one)
├── Cachex               — memoizes successful lookup results
├── Ip2Asn.Store         — GenServer holding a Rust NIF reference to the compiled dataset
└── Ip2Asn.Updater       — GenServer that downloads, decompresses, and loads the dataset;
                           schedules a refresh every 24 hours
```

The dataset (~42 MB uncompressed TSV) is downloaded from `https://iptoasn.com/data/ip2asn-combined.tsv.gz`, decompressed, and compiled into an in-memory binary search tree by the Rust NIF. A local copy is cached in `priv/ip2asn-combined.tsv` and reused on restart if it is less than 24 hours old.

## Requirements

- Elixir `~> 1.19`
- OTP 24+
- Rust 1.56+ (edition 2021, via `rustup`)

## License

See [LICENSE](LICENSE) for details.

