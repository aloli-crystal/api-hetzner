require "json"

module HetznerApi
  module Endpoints
    # Endpoints `/boot/{server_number}/*` — bascule en rescue.
    #
    # Hetzner expose plusieurs modes de boot (`/boot/{n}/linux`,
    # `/boot/{n}/vnc`, `/boot/{n}/windows`, `/boot/{n}/cpanel`,
    # `/boot/{n}/plesk`, `/boot/{n}/rescue`). Pour beryl, seul le
    # mode rescue nous intéresse — c'est l'image Linux unique
    # Hetzner qui sert d'environnement pour mfsBSD-in-QEMU.
    #
    # Particularité Hetzner : le rescue est *one-shot*. Une fois
    # activé, le prochain boot charge le rescue ; après ce reboot
    # le flag `active` repasse à `false` côté backend, et tout
    # nouveau reboot revient sur le disque normalement. Pas
    # d'équivalent à `boot_normal` Dedibox — le retour disque est
    # automatique.
    class Boot
      def initialize(@client : HetznerApi::Client)
      end

      # Lit la configuration rescue actuelle d'un serveur.
      #
      # `GET /boot/{server_number}/rescue` →
      # `{"rescue": {"active": true|false, "os": "linux", ...}}`.
      def rescue_status(server_number : Int32) : RescueConfig
        result = @client.call("GET", "/boot/#{server_number}/rescue").not_nil!
        RescueConfig.from_any(result["rescue"].not_nil!)
      end

      # Active le mode rescue Linux pour le prochain boot.
      #
      # `POST /boot/{server_number}/rescue` avec :
      #   * `os` (obligatoire) : `linux` ou `vkvm`. Pas de Debian /
      #     Ubuntu / FreeBSD au choix — c'est l'image rescue unique
      #     Hetzner.
      #   * `authorized_key[]` (optionnel) : liste de fingerprints
      #     SSH déjà enregistrés via `client.ssh_keys`. Permet de
      #     bypasser le password root généré.
      #   * `keyboard` (optionnel, défaut `us`).
      #
      # Si `authorized_keys` est non vide, le rescue accepte la
      # clé SSH ; sinon, l'opérateur doit utiliser le `password`
      # retourné dans la réponse (visible une seule fois).
      #
      # Le shard ne wrap PAS le rescue VKVM ni les modes
      # `/boot/{n}/linux` (boot d'un OS spécifique). beryl utilise
      # uniquement le rescue Linux comme tremplin pour mfsBSD.
      def activate_rescue(
        server_number : Int32,
        os : String = "linux",
        authorized_keys : Array(String) = [] of String,
        keyboard : String? = nil,
      ) : RescueConfig
        # Construction du form-urlencoded à la main pour gérer les
        # entrées multi-valued `authorized_key[]=...`. Hetzner attend
        # strictement ce format quand plusieurs clés sont passées.
        parts = [] of String
        parts << "os=#{URI.encode_www_form(os)}"
        parts << "keyboard=#{URI.encode_www_form(keyboard)}" if keyboard
        authorized_keys.each do |fp|
          parts << "authorized_key%5B%5D=#{URI.encode_www_form(fp)}"
        end
        body = parts.join("&")

        result = @client.call_raw(
          "POST", "/boot/#{server_number}/rescue",
          body: body,
          content_type: "application/x-www-form-urlencoded",
        ).not_nil!
        RescueConfig.from_any(result["rescue"].not_nil!)
      end

      # Désactive explicitement le rescue avant le prochain reboot.
      # Utile si on a activé le rescue et qu'on change d'avis avant
      # de redémarrer (sinon le rescue reste planifié pour le
      # prochain boot).
      #
      # `DELETE /boot/{server_number}/rescue`.
      def deactivate_rescue(server_number : Int32) : Nil
        @client.call("DELETE", "/boot/#{server_number}/rescue")
      end

      # Lit la configuration rescue précédemment active (avant le
      # dernier reboot, donc dans le boot disque actuel).
      #
      # `GET /boot/{server_number}/rescue/last`.
      def last_rescue(server_number : Int32) : RescueConfig
        result = @client.call("GET", "/boot/#{server_number}/rescue/last").not_nil!
        RescueConfig.from_any(result["rescue"].not_nil!)
      end
    end

    # Configuration rescue retournée par l'API.
    struct RescueConfig
      getter server_number : Int32
      getter os : String?
      getter active : Bool
      getter password : String?
      getter authorized_key : Array(String)
      getter host_key : Array(JSON::Any)
      getter raw : JSON::Any

      def initialize(
        @server_number : Int32,
        @active : Bool,
        @raw : JSON::Any,
        @os : String? = nil,
        @password : String? = nil,
        @authorized_key : Array(String) = [] of String,
        @host_key : Array(JSON::Any) = [] of JSON::Any,
      )
      end

      def self.from_any(payload : JSON::Any) : RescueConfig
        ak = payload["authorized_key"]?.try(&.as_a?).try(&.compact_map(&.as_s?)) || [] of String
        hk = payload["host_key"]?.try(&.as_a?) || [] of JSON::Any
        new(
          server_number: payload["server_number"].as_i,
          active: payload["active"]?.try(&.as_bool?) || false,
          os: payload["os"]?.try(&.as_s?),
          password: payload["password"]?.try(&.as_s?),
          authorized_key: ak,
          host_key: hk,
          raw: payload,
        )
      end
    end
  end
end
