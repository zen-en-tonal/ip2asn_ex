defmodule Ip2Asn.PlugTest do
  use ExUnit.Case
  import Plug.Test

  @test_data "31.13.64.0\t31.13.127.255\t32934\tUS\tFACEBOOK-AS"

  setup do
    :ok = Ip2Asn.Store.update(@test_data)
    Cachex.clear(:ip2asn_cache)
    :ok
  end

  test "assigns ASN info for a known IPv4 address" do
    opts = Ip2Asn.Plug.init([])
    conn = conn(:get, "/") |> Map.put(:remote_ip, {31, 13, 100, 100})
    conn = Ip2Asn.Plug.call(conn, opts)

    assert %{asn: 32934, country_code: "US", organization: "FACEBOOK-AS"} =
             conn.assigns.asn_info
  end

  test "assigns nil for an unknown IP when on_error is :ignore (default)" do
    opts = Ip2Asn.Plug.init([])
    conn = conn(:get, "/") |> Map.put(:remote_ip, {8, 8, 8, 8})
    conn = Ip2Asn.Plug.call(conn, opts)

    assert conn.assigns.asn_info == nil
    refute conn.halted
  end

  test "halts with 403 for an unknown IP when on_error is :halt" do
    opts = Ip2Asn.Plug.init(on_error: :halt)
    conn = conn(:get, "/") |> Map.put(:remote_ip, {8, 8, 8, 8})
    conn = Ip2Asn.Plug.call(conn, opts)

    assert conn.halted
    assert conn.status == 403
  end

  test "respects a custom :assign_as key" do
    opts = Ip2Asn.Plug.init(assign_as: :client_asn)
    conn = conn(:get, "/") |> Map.put(:remote_ip, {31, 13, 100, 100})
    conn = Ip2Asn.Plug.call(conn, opts)

    assert conn.assigns.client_asn.asn == 32934
    refute Map.has_key?(conn.assigns, :asn_info)
  end

  test "formats IPv6 remote_ip tuples correctly" do
    # ::1 (loopback) is unlikely to be in the dataset → nil assign, no crash.
    opts = Ip2Asn.Plug.init([])
    conn = conn(:get, "/") |> Map.put(:remote_ip, {0, 0, 0, 0, 0, 0, 0, 1})
    conn = Ip2Asn.Plug.call(conn, opts)

    assert conn.assigns.asn_info == nil
    refute conn.halted
  end
end
