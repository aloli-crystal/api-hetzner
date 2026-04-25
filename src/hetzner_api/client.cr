require "base64"
require "http/client"
require "json"
require "uri"

require "./errors"

module HetznerApi
  # URL de base de l'API Hetzner Robot Webservice. Hôte unique pour
  # toutes les opérations (pas de routage par zone comme Scaleway).
  # HTTPS exclusivement — pas de HTTP en clair côté Hetzner.
  BASE_URL = "https://robot-ws.your-server.de"

  # Transport HTTP abstrait. Permet d'injecter un double en test.
  #
  # Une implémentation doit retourner un tuple `{status, body}`. Le
  # `Client` se charge de décoder le JSON et de lever les exceptions.
  abstract class HttpTransport
    abstract def request(
      method : String,
      url : String,
      headers : HTTP::Headers,
      body : String,
    ) : {Int32, String}
  end

  # Implémentation par défaut basée sur `HTTP::Client` de la stdlib.
  class DefaultHttpTransport < HttpTransport
    def request(method, url, headers, body) : {Int32, String}
      uri = URI.parse(url)
      response = HTTP::Client.exec(
        method: method,
        url: uri,
        headers: headers,
        body: body,
      )
      {response.status_code, response.body}
    end
  end

  # Client Hetzner Robot Webservice.
  #
  # Authentification : HTTP Basic via un *web service user* dédié,
  # créé dans le panel Robot (Settings → Web service and app
  # settings). Distinct du compte Robot principal.
  #
  # ```
  # client = HetznerApi::Client.new(
  #   username: ENV["HETZNER_WS_USER"],
  #   password: ENV["HETZNER_WS_PASSWORD"],
  # )
  #
  # # Liste des serveurs
  # client.servers.list.each { |s| puts s.server_number }
  #
  # # Bascule en rescue Linux avec une clé SSH déjà enregistrée
  # client.boot.activate_rescue(
  #   server_number: 321,
  #   authorized_keys: ["aa:bb:cc:dd:..."],
  # )
  # client.reset.execute(server_number: 321, type: HetznerApi::ResetType::HW)
  # ```
  class Client
    getter username : String
    getter base_url : String

    # Injection du transport HTTP (par défaut `DefaultHttpTransport`).
    # En test, passer un double qui renvoie `{status, body}` prédéfini.
    property transport : HttpTransport

    def initialize(
      @username : String,
      @password : String,
      @base_url : String = BASE_URL,
      @transport : HttpTransport = DefaultHttpTransport.new,
    )
    end

    # Effectue un appel HTTP vers l'API.
    #
    # Hetzner Robot accepte les paramètres :
    #   - en query string pour les GET / DELETE (rares)
    #   - en form-urlencoded dans le body pour les POST / PUT
    #
    # Le format de réponse est JSON par défaut. Le shard ne demande
    # pas YAML (suffix `.yaml`) — JSON est plus universel.
    #
    # `body_form` : Hash de params à encoder en
    # `application/x-www-form-urlencoded` (cas POST/PUT). Nil = pas
    # de body (cas GET/DELETE).
    #
    # `query` : Hash de params à mettre en query string (cas GET).
    #
    # Lève l'exception adaptée selon le code HTTP :
    #   - 401 → `AuthenticationError`
    #   - 403 + `RATE_LIMIT_EXCEEDED` → `RateLimited`
    #   - 404 → `NotFound`
    #   - 409 → `Conflict`
    #   - 503 → `MaintenanceMode`
    #   - autre 4xx/5xx → `ApiError`
    def call(
      method : String,
      path : String,
      query : Hash(String, String)? = nil,
      body_form : Hash(String, String)? = nil,
    ) : JSON::Any?
      body_string = body_form ? URI::Params.encode(body_form) : ""
      content_type = body_form ? "application/x-www-form-urlencoded" : nil
      call_raw(method, path, query, body_string, content_type)
    end

    # Variante qui accepte un body string déjà encodé. Utile pour
    # les endpoints Hetzner qui exigent des params multi-valued
    # `authorized_key[]=fp1&authorized_key[]=fp2`, qu'un Hash
    # Crystal mono-valued ne peut pas représenter.
    def call_raw(
      method : String,
      path : String,
      query : Hash(String, String)? = nil,
      body : String = "",
      content_type : String? = nil,
    ) : JSON::Any?
      url = @base_url + path
      if query && !query.empty?
        url += "?" + URI::Params.encode(query)
      end

      headers = HTTP::Headers.new
      headers["Authorization"] = "Basic " + Base64.strict_encode("#{@username}:#{@password}")
      headers["Accept"] = "application/json"
      headers["Content-Type"] = content_type if content_type

      status, response_body = @transport.request(method, url, headers, body)
      handle_response(status, response_body)
    end

    private def handle_response(status : Int32, body : String) : JSON::Any?
      # 204 No Content / 200 sans body
      return nil if body.empty?

      parsed = begin
        JSON.parse(body)
      rescue
        nil
      end

      case status
      when 200, 201, 202, 204
        parsed
      when 401
        raise AuthenticationError.new(extract_message(parsed) || "authentification refusée (web service user / password)")
      when 403
        code = extract_error_code(parsed)
        if code == "RATE_LIMIT_EXCEEDED"
          raise RateLimited.new(
            extract_message(parsed) || "rate limit dépassé",
            max_request: extract_int(parsed, "max_request"),
            interval: extract_int(parsed, "interval"),
          )
        end
        raise ApiError.new(extract_message(parsed) || "accès refusé", status, code)
      when 404
        raise NotFound.new(extract_message(parsed) || "ressource introuvable")
      when 409
        raise Conflict.new(extract_message(parsed) || "conflit")
      when 503
        raise MaintenanceMode.new(extract_message(parsed) || "maintenance Hetzner")
      else
        raise ApiError.new(
          extract_message(parsed) || "Hetzner API #{status}",
          status,
          extract_error_code(parsed),
        )
      end
    end

    private def extract_message(parsed : JSON::Any?) : String?
      err = parsed.try(&.["error"]?)
      err.try(&.["message"]?).try(&.as_s?)
    end

    private def extract_error_code(parsed : JSON::Any?) : String?
      err = parsed.try(&.["error"]?)
      err.try(&.["code"]?).try(&.as_s?)
    end

    private def extract_int(parsed : JSON::Any?, key : String) : Int32?
      err = parsed.try(&.["error"]?)
      err.try(&.[key]?).try(&.as_i?)
    end

    # Accès paresseux aux endpoints. Chaque sous-client réutilise le
    # même `self`, donc la même config et le même transport.

    def servers : Endpoints::Servers
      @servers ||= Endpoints::Servers.new(self)
    end

    def ssh_keys : Endpoints::SshKeys
      @ssh_keys ||= Endpoints::SshKeys.new(self)
    end

    def boot : Endpoints::Boot
      @boot ||= Endpoints::Boot.new(self)
    end

    def reset : Endpoints::Reset
      @reset ||= Endpoints::Reset.new(self)
    end

    def rdns : Endpoints::Rdns
      @rdns ||= Endpoints::Rdns.new(self)
    end

    @servers : Endpoints::Servers?
    @ssh_keys : Endpoints::SshKeys?
    @boot : Endpoints::Boot?
    @reset : Endpoints::Reset?
    @rdns : Endpoints::Rdns?
  end
end
