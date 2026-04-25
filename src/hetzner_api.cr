require "./hetzner_api/version"
require "./hetzner_api/errors"
require "./hetzner_api/endpoints/servers"
require "./hetzner_api/endpoints/ssh_keys"
require "./hetzner_api/endpoints/boot"
require "./hetzner_api/endpoints/reset"
require "./hetzner_api/endpoints/rdns"
require "./hetzner_api/client"

# HetznerApi — client Crystal pur (stdlib uniquement) pour l'API
# Hetzner Robot Webservice (https://robot-ws.your-server.de).
#
# Cible exclusive : *les serveurs dédiés bare-metal classiques*
# (mensuels, gammes EX/AX/SX). À NE PAS confondre avec :
#
# * Hetzner Cloud API (`api.hetzner.cloud`) — pour les VPS, autre
#   produit, autre API, SDK officiels Go/Python disponibles côté
#   Hetzner. Ce shard ne couvre PAS Hetzner Cloud.
# * Hetzner DNS Console API (`dns.hetzner.com/api`) — gestion de
#   zones DNS publiques, sans rapport avec le bare-metal.
#
# Couvre le strict nécessaire au flow beryl :
#
# * `client.servers`   — lister / lire les serveurs du compte.
# * `client.ssh_keys`  — CRUD des clés SSH (identifiant = fingerprint
#                        MD5 colon-separated). `ensure(name, pubkey)`
#                        idempotent.
# * `client.boot`      — bascule en rescue Linux (one-shot).
#                        Retour disque automatique au reboot suivant
#                        (pas d'équivalent `boot_normal` Dedibox).
# * `client.reset`     — reboot bare-metal (sw/hw/man/power/power_long).
# * `client.rdns`      — reverse DNS par IP, idempotent (POST upsert).
#
# Authentification : *HTTP Basic* via un *web service user* dédié
# créé dans le panel Robot (Settings → Web service and app
# settings). Distinct du compte Robot principal.
#
# ATTENTION lockout : 3 échecs d'auth depuis une même IP source
# bloquent cette IP pendant 10 minutes. Le shard ne fait PAS de
# retry automatique sur 401.
#
# ```
# require "hetzner-api"
#
# client = HetznerApi::Client.new(
#   username: ENV["HETZNER_WS_USER"],
#   password: ENV["HETZNER_WS_PASSWORD"],
# )
#
# # Liste des serveurs
# client.servers.list.each do |s|
#   puts "##{s.server_number}  #{s.server_ip}  #{s.product}"
# end
#
# # Inscrire une clé SSH (idempotent — pas d'erreur si déjà là)
# key = client.ssh_keys.ensure(
#   name: "philippe.aloli.fr",
#   public_key: File.read(ENV["HOME"] + "/.ssh/philippe.aloli.fr.pub"),
# )
#
# # Activer le rescue Linux avec auth par clé
# client.boot.activate_rescue(
#   server_number: 321,
#   authorized_keys: [key.fingerprint],
# )
#
# # Trigger le hardware reset → boot dans le rescue
# client.reset.execute(server_number: 321, type: HetznerApi::Endpoints::ResetType::HW)
#
# # Plus tard, après l'install FreeBSD : reboot disque
# # (le rescue one-shot est désactivé automatiquement)
# client.reset.execute(server_number: 321, type: HetznerApi::Endpoints::ResetType::HW)
#
# # Poser le reverse DNS
# client.rdns.set(ip: "1.2.3.4", ptr: "myhost.aloli.fr")
# ```
module HetznerApi
end
