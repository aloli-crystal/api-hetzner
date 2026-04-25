require "json"

module HetznerApi
  module Endpoints
    # Endpoints `/server` — gestion des serveurs dédiés du compte.
    #
    # L'identifiant canonique est le `server_number` (entier court,
    # ex: 321). L'`server_ip` est accepté en mode `@deprecated` mais
    # ce shard n'utilise QUE `server_number` pour les autres endpoints.
    class Servers
      def initialize(@client : HetznerApi::Client)
      end

      # Liste tous les serveurs du compte.
      #
      # `GET /server` → tableau d'objets `{"server": {...}}`.
      def list : Array(Server)
        result = @client.call("GET", "/server")
        arr = result.try(&.as_a?) || [] of JSON::Any
        arr.compact_map do |item|
          payload = item["server"]?
          payload ? Server.from_any(payload) : nil
        end
      end

      # Détail d'un serveur par numéro.
      #
      # `GET /server/{server_number}` → `{"server": {...}}`.
      def get(server_number : Int32) : Server
        result = @client.call("GET", "/server/#{server_number}").not_nil!
        Server.from_any(result["server"].not_nil!)
      end
    end

    # Représente un serveur dédié Hetzner.
    #
    # Champs principaux exposés. Le JSON brut complet est gardé dans
    # `raw` pour les champs non parsés explicitement (status, traffic,
    # cancelled, paid_until, subnet, etc.).
    struct Server
      getter server_ip : String?
      getter server_ipv6_net : String?
      getter server_number : Int32
      getter server_name : String?
      getter product : String?
      getter dc : String?
      getter status : String?
      getter raw : JSON::Any

      def initialize(
        @server_number : Int32,
        @raw : JSON::Any,
        @server_ip : String? = nil,
        @server_ipv6_net : String? = nil,
        @server_name : String? = nil,
        @product : String? = nil,
        @dc : String? = nil,
        @status : String? = nil,
      )
      end

      def self.from_any(payload : JSON::Any) : Server
        new(
          server_number: payload["server_number"].as_i,
          server_ip: payload["server_ip"]?.try(&.as_s?),
          server_ipv6_net: payload["server_ipv6_net"]?.try(&.as_s?),
          server_name: payload["server_name"]?.try(&.as_s?),
          product: payload["product"]?.try(&.as_s?),
          dc: payload["dc"]?.try(&.as_s?),
          status: payload["status"]?.try(&.as_s?),
          raw: payload,
        )
      end
    end
  end
end
