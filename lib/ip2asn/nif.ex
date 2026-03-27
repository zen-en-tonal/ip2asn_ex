defmodule Ip2Asn.Nif do
  use Rustler,
    otp_app: :ip2asn,
    crate: :ip2asn_nif

  def build(_bin), do: :erlang.nif_error(:nif_not_loaded)
  def lookup(_ref, _ip), do: :erlang.nif_error(:nif_not_loaded)
end
