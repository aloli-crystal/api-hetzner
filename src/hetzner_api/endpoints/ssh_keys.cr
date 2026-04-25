require "json"

module HetznerApi
  module Endpoints
    # Endpoints `/key` — gestion des clés SSH du compte.
    #
    # L'identifiant primaire est le **fingerprint MD5
    # colon-separated** (format historique `aa:bb:cc:...`), pas
    # SHA256-base64. L'unicité se fait sur ce fingerprint :
    # poster deux fois la même clé = `409 KEY_ALREADY_EXISTS`.
    #
    # Pour l'idempotence, le shard expose `ensure(name, public_key)`
    # qui combine `list` + `create` ou `rename` selon présence.
    class SshKeys
      def initialize(@client : HetznerApi::Client)
      end

      # Liste toutes les clés SSH du compte.
      #
      # `GET /key` → tableau de `{"key": {...}}`.
      def list : Array(SshKey)
        result = @client.call("GET", "/key")
        arr = result.try(&.as_a?) || [] of JSON::Any
        arr.compact_map do |item|
          payload = item["key"]?
          payload ? SshKey.from_any(payload) : nil
        end
      end

      # Détail d'une clé par fingerprint.
      def get(fingerprint : String) : SshKey
        result = @client.call("GET", "/key/#{fingerprint}").not_nil!
        SshKey.from_any(result["key"].not_nil!)
      end

      # Crée une clé SSH.
      #
      # `POST /key` avec `name` + `data` (clé publique complète au
      # format OpenSSH `ssh-ed25519 AAAA... commentaire`).
      #
      # Lève `Conflict` (HTTP 409, error_code `KEY_ALREADY_EXISTS`)
      # si une clé avec le même fingerprint est déjà enregistrée.
      def create(name : String, public_key : String) : SshKey
        result = @client.call(
          "POST", "/key",
          body_form: {"name" => name, "data" => public_key},
        ).not_nil!
        SshKey.from_any(result["key"].not_nil!)
      end

      # Renomme une clé existante (le seul champ modifiable côté
      # Hetzner — pour changer le matériel cryptographique, il faut
      # `delete` puis `create`).
      #
      # `POST /key/{fingerprint}` avec `name`.
      def rename(fingerprint : String, name : String) : SshKey
        result = @client.call(
          "POST", "/key/#{fingerprint}",
          body_form: {"name" => name},
        ).not_nil!
        SshKey.from_any(result["key"].not_nil!)
      end

      # Supprime une clé par fingerprint.
      def delete(fingerprint : String) : Nil
        @client.call("DELETE", "/key/#{fingerprint}")
      end

      # Idempotent : s'assure qu'une clé avec ce `public_key` existe.
      # Retourne la `SshKey` (existante ou créée). Si elle existait
      # déjà avec un nom différent, le nom n'est PAS écrasé (Hetzner
      # n'autoriserait que `rename` qui change l'ID — non sûr).
      def ensure(name : String, public_key : String) : SshKey
        # Hetzner Robot ne fournit pas de moyen de chercher par
        # contenu de clé directement — on liste tout et compare le
        # `data` (clé publique). La liste est limitée à quelques
        # dizaines en pratique.
        existing = list.find do |k|
          # Compare en ignorant le commentaire trailing (le 3e champ
          # OpenSSH n'est pas significatif).
          k.data.split(/\s+/).first(2) == public_key.split(/\s+/).first(2)
        end
        existing || create(name, public_key)
      end
    end

    # Détail d'une clé SSH Hetzner.
    struct SshKey
      getter name : String
      getter fingerprint : String
      getter type : String
      getter size : Int32
      getter data : String
      getter created_at : String?
      getter raw : JSON::Any

      def initialize(
        @name : String,
        @fingerprint : String,
        @type : String,
        @size : Int32,
        @data : String,
        @raw : JSON::Any,
        @created_at : String? = nil,
      )
      end

      def self.from_any(payload : JSON::Any) : SshKey
        new(
          name: payload["name"].as_s,
          fingerprint: payload["fingerprint"].as_s,
          type: payload["type"].as_s,
          size: payload["size"].as_i,
          data: payload["data"].as_s,
          created_at: payload["created_at"]?.try(&.as_s?),
          raw: payload,
        )
      end
    end
  end
end
