defmodule Ip2AsnTest do
  use ExUnit.Case

  @test_data "31.13.64.0\t31.13.127.255\t32934\tUS\tFACEBOOK-AS"

  setup do
    # Load test data directly into the store (auto_update is disabled in test env).
    :ok = Ip2Asn.Store.update(@test_data)
    Cachex.clear(:ip2asn_cache)
    :ok
  end

  test "lookup returns ASN info for a known IP" do
    assert {:ok, info} = Ip2Asn.lookup("31.13.100.100")
    assert info.asn == 32934
    assert info.country_code == "US"
    assert info.organization == "FACEBOOK-AS"
    assert info.network == "31.13.64.0/18"
  end

  test "lookup returns an error for an unknown IP" do
    assert {:error, _} = Ip2Asn.lookup("8.8.8.8")
  end

  test "repeated lookup returns cached result" do
    assert {:ok, _} = Ip2Asn.lookup("31.13.100.100")
    # The result should now be in the cache.
    assert {:ok, cached} = Cachex.get(:ip2asn_cache, "31.13.100.100")
    assert {:ok, info} = cached
    assert info.asn == 32934
  end

  test "Store.update replaces the dataset" do
    :ok = Ip2Asn.Store.update("1.0.0.0\t1.0.0.255\t13335\tAU\tCLOUDFLARENET")
    assert {:ok, info} = Ip2Asn.Store.lookup("1.0.0.1")
    assert info.asn == 13335
  end
end
