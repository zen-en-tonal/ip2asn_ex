defmodule Ip2Asn do
  @moduledoc """
  Documentation for `Ip2Asn`.

  ## Examples
      iex> data = "31.13.64.0\t31.13.127.255\t32934\tUS\tFACEBOOK-AS"
      iex> {:ok, ref} = Ip2Asn.build(data)
      iex> Ip2Asn.lookup(ref, "31.13.100.100")
      {:ok, %{
        organization: "FACEBOOK-AS",
        network: "31.13.64.0/18",
        asn: 32934,
        country_code: "US"
      }}
      iex> Ip2Asn.lookup(ref, "8.8.8.8")
      {:error, :not_found}
  """

  @type t :: reference()

  @type asn_info :: %{
          network: binary(),
          asn: non_neg_integer(),
          country_code: binary(),
          organization: binary()
        }

  @spec build(binary()) :: {:ok, t()} | {:error, term()}
  def build(bin) do
    case Ip2Asn.Nif.build(bin) do
      {:ok, ref} -> {:ok, ref}
      other -> {:error, other}
    end
  end

  @spec lookup(t(), binary()) :: {:ok, asn_info()} | {:error, term()}
  def lookup(ref, ip) do
    case Ip2Asn.Nif.lookup(ref, ip) do
      {:ok, info} -> {:ok, info}
      other -> {:error, other}
    end
  end
end
