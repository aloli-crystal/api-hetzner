require "json"

module HetznerApi
  module Endpoints
    # Endpoints `/rdns/{ip}` — gestion du reverse DNS par IP.
    #
    # Hetzner expose le PTR via API publique (contrairement à
    # Dedibox qui force l'opérateur à passer par la console). Bon
    # point pour beryl : on peut tout faire en automatique.
    #
    # `PUT` crée un PTR (refuse si déjà existant — `409
    # RDNS_ALREADY_EXISTS`). `POST` upsert (crée ou met à jour).
    # Pour la simplicité côté beryl, on utilise systématiquement
    # `set` (qui appelle POST) — l'idempotence est gratuite.
    class Rdns
      def initialize(@client : HetznerApi::Client)
      end

      # Liste tous les PTR du compte.
      #
      # `GET /rdns` → tableau de `{"rdns": {"ip": "...", "ptr": "..."}}`.
      def list : Array(RdnsRecord)
        result = @client.call("GET", "/rdns")
        arr = result.try(&.as_a?) || [] of JSON::Any
        arr.compact_map do |item|
          payload = item["rdns"]?
          payload ? RdnsRecord.from_any(payload) : nil
        end
      end

      # Lit le PTR pour une IP.
      #
      # `GET /rdns/{ip}`. Lève `NotFound` si aucun PTR posé.
      def get(ip : String) : RdnsRecord
        result = @client.call("GET", "/rdns/#{ip}").not_nil!
        RdnsRecord.from_any(result["rdns"].not_nil!)
      end

      # Pose ou met à jour le PTR pour une IP. Idempotent (utilise
      # `POST` côté Hetzner = upsert).
      #
      # `POST /rdns/{ip}` avec `ptr=<fqdn>`.
      def set(ip : String, ptr : String) : RdnsRecord
        result = @client.call(
          "POST", "/rdns/#{ip}",
          body_form: {"ptr" => ptr},
        ).not_nil!
        RdnsRecord.from_any(result["rdns"].not_nil!)
      end

      # Supprime le PTR pour une IP.
      #
      # `DELETE /rdns/{ip}`. Hetzner remettra une valeur par défaut
      # générique (`staticXXX.host.example`) au lieu de pas de PTR
      # du tout.
      def delete(ip : String) : Nil
        @client.call("DELETE", "/rdns/#{ip}")
      end
    end

    # Un enregistrement reverse DNS Hetzner.
    struct RdnsRecord
      getter ip : String
      getter ptr : String

      def initialize(@ip : String, @ptr : String)
      end

      def self.from_any(payload : JSON::Any) : RdnsRecord
        new(
          ip: payload["ip"].as_s,
          ptr: payload["ptr"].as_s,
        )
      end
    end
  end
end
