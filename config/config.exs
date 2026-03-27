import Config

# Auto-update the ip2asn dataset from iptoasn.com on startup and every 24h.
# Set to false in tests to avoid network calls.
config :ip2asn, auto_update: true

if config_env() == :test do
  config :ip2asn, auto_update: false
end
