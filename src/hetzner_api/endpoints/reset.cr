require "json"

module HetznerApi
  module Endpoints
    # Type de reset accepté par `Reset#execute`. Les valeurs
    # exactes dépendent du serveur — `Reset#types_for(server_number)`
    # remonte la liste depuis l'API.
    enum ResetType
      # Software reset (équivalent `Ctrl+Alt+Suppr`).
      SW
      # Hardware reset (bouton reset physique). Le mode UTILE pour
      # basculer du PXE rescue vers le boot disque dans le flow
      # beryl, et pour rebooter en rescue après activation.
      HW
      # Reset manuel par un technicien Hetzner. Déclenche un ticket
      # support — pas pour beryl en flow nominal.
      MAN
      # Power off / on bref (sur certains serveurs avec gestion ATX
      # par l'API).
      POWER
      # Power button long press.
      PowerLong

      def to_api : String
        case self
        in SW        then "sw"
        in HW        then "hw"
        in MAN       then "man"
        in POWER     then "power"
        in PowerLong then "power_long"
        end
      end

      def self.from_api(s : String) : ResetType
        case s
        when "sw"         then SW
        when "hw"         then HW
        when "man"        then MAN
        when "power"      then POWER
        when "power_long" then PowerLong
        else                   raise ArgumentError.new("type de reset inconnu : #{s}")
        end
      end
    end

    # Endpoints `/reset/{server_number}` — reboot bare-metal.
    #
    # ATTENTION : `POST /reset` est rate-limité à *50 requêtes par
    # heure*, le plus serré des endpoints Hetzner Robot. Pas de
    # spam de reboot pendant les itérations beryl.
    class Reset
      def initialize(@client : HetznerApi::Client)
      end

      # Liste les types de reset supportés par ce serveur.
      #
      # `GET /reset/{server_number}` → typiquement `["sw","hw","man"]`
      # ou `["power","power_long","hw","man"]` selon le matériel.
      def types_for(server_number : Int32) : Array(ResetType)
        result = @client.call("GET", "/reset/#{server_number}").not_nil!
        types_arr = result["reset"]?.try(&.["type"]?).try(&.as_a?) || [] of JSON::Any
        types_arr.compact_map(&.as_s?).map { |s| ResetType.from_api(s) }
      end

      # Déclenche un reset.
      #
      # `POST /reset/{server_number}` avec `type=hw` (ou autre).
      #
      # Pour beryl :
      #   - après `boot.activate_rescue` → `execute(n, ResetType::HW)`
      #   - après l'install FreeBSD pour booter sur le disque →
      #     `execute(n, ResetType::HW)` (le rescue one-shot est
      #     auto-désactivé, le boot disque suit naturellement)
      def execute(server_number : Int32, type : ResetType = ResetType::HW) : Nil
        @client.call(
          "POST", "/reset/#{server_number}",
          body_form: {"type" => type.to_api},
        )
      end
    end
  end
end
