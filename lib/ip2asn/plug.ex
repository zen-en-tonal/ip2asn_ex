if Code.ensure_loaded?(Plug.Conn) do
  defmodule Ip2Asn.Plug do
    @moduledoc """
    A Plug middleware that enriches the connection with ASN information
    derived from the client's remote IP address.

    The lookup result is stored in `conn.assigns` under a configurable key.
    When the IP is not found (or the dataset is not yet loaded) the middleware
    can either assign `nil` and continue, or halt the request with a 403.

    ## Options

      * `:assign_as` – atom key used in `conn.assigns`.
        Defaults to `:asn_info`.

      * `:on_error` – behaviour when the lookup fails:
          * `:ignore` *(default)* – assign `nil` and pass the conn through.
          * `:halt` – respond with `403 Forbidden` and halt the pipeline.

    ## Usage

        # In a Phoenix router or endpoint:
        plug Ip2Asn.Plug

        # With options:
        plug Ip2Asn.Plug, assign_as: :client_asn, on_error: :halt

    ## Accessing the result downstream

        def call(conn, _opts) do
          case conn.assigns[:asn_info] do
            %{asn: asn, country_code: cc} ->
              Logger.info("Request from ASN \#{asn} (\#{cc})")
            nil ->
              :ok
          end
          conn
        end

    ## Requirements

    Add `{:plug, ">= 1.0"}` to your application's dependencies to use this
    module. `Ip2Asn` lists Plug as an optional dependency so it is not pulled
    in automatically.
    """

    @behaviour Plug

    import Plug.Conn

    @impl Plug
    def init(opts) do
      %{
        assign_as: Keyword.get(opts, :assign_as, :asn_info),
        on_error: Keyword.get(opts, :on_error, :ignore)
      }
    end

    @impl Plug
    def call(conn, %{assign_as: key, on_error: on_error}) do
      ip = to_ip_string(conn.remote_ip)

      case Ip2Asn.lookup(ip) do
        {:ok, info} ->
          assign(conn, key, info)

        {:error, _} when on_error == :ignore ->
          assign(conn, key, nil)

        {:error, _} ->
          conn
          |> send_resp(403, "Forbidden")
          |> halt()
      end
    end

    # Converts an Erlang IP tuple ({a,b,c,d} or 8-element IPv6 tuple) to a
    # printable string using the standard library formatter.
    defp to_ip_string(ip_tuple) do
      ip_tuple |> :inet.ntoa() |> to_string()
    end
  end
end
