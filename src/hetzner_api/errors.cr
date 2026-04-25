module HetznerApi
  # Base de la hiérarchie d'exceptions HetznerApi.
  #
  # Toutes les erreurs remontées par ce shard descendent de
  # `HetznerApi::Error`, ce qui permet à l'appelant de rattraper
  # l'ensemble avec un seul `rescue`.
  class Error < Exception
  end

  # Erreur d'authentification : login/password du web service user
  # incorrects, ou web service user non créé dans le panel Robot.
  # Correspond à HTTP 401.
  #
  # ATTENTION : 3 échecs d'auth depuis une même IP source bloquent
  # cette IP pendant 10 minutes côté Hetzner. Le shard ne fait PAS
  # de retry automatique sur 401 pour éviter le lockout.
  class AuthenticationError < Error
  end

  # Ressource inexistante. Correspond à HTTP 404.
  class NotFound < Error
  end

  # Conflit avec l'état actuel. Correspond à HTTP 409.
  # Cas typiques :
  #   - `KEY_ALREADY_EXISTS` : la clé SSH (par fingerprint) est
  #     déjà enregistrée. L'appelant peut soit ignorer (idempotence
  #     via GET-puis-POST), soit la supprimer et la recréer.
  #   - `RDNS_ALREADY_EXISTS` : un PTR existe déjà pour cette IP
  #     (sur PUT). Utiliser POST pour upsert au lieu de PUT.
  class Conflict < Error
  end

  # Quota dépassé. Correspond à HTTP 403 RATE_LIMIT_EXCEEDED.
  # Hetzner Robot expose des limites par endpoint, par exemple :
  #   - 50/h pour POST /reset
  #   - 200/h pour les écritures /key
  #   - 500/h pour les lectures et la plupart des autres endpoints
  #
  # Le corps JSON contient les champs `max_request` et `interval`
  # (en secondes), accessibles via `RateLimited#max_request` et
  # `RateLimited#interval`.
  class RateLimited < Error
    getter max_request : Int32?
    getter interval : Int32?

    def initialize(message : String, @max_request : Int32? = nil, @interval : Int32? = nil)
      super(message)
    end
  end

  # Maintenance Hetzner. Correspond à HTTP 503.
  # Distinct d'une erreur 5xx applicative — l'appelant peut
  # éventuellement faire un retry borné.
  class MaintenanceMode < Error
  end

  # Erreur générique remontée par l'API Hetzner Robot : message,
  # code HTTP et `error_code` Hetzner (champ `code` du corps JSON,
  # ex. `KEY_ALREADY_EXISTS`, `IP_NOT_FOUND`, `BOOT_NOT_AVAILABLE`).
  #
  # L'API Hetzner suit le format `{"error": {"status": ..., "code":
  # "...", "message": "..."}}`.
  class ApiError < Error
    getter http_status : Int32
    getter error_code : String?

    def initialize(message : String, @http_status : Int32, @error_code : String? = nil)
      super(message)
    end
  end
end
