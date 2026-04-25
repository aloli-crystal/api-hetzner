require "spec"
require "../src/hetzner_api"

# Transport HTTP factice : stocke les requêtes reçues et renvoie des
# réponses pré-programmées. Purement stdlib, aucune dépendance externe.
#
# Usage dans les specs :
#
# ```
# transport = FakeTransport.new
# transport.stub("GET", /server/, status: 200, body: %([{"server":{...}}]))
#
# client = HetznerApi::Client.new(
#   username: "ws+aloli",
#   password: "secret",
#   transport: transport,
# )
# servers = client.servers.list
#
# # Inspection
# transport.requests.last.headers["Authorization"].should start_with("Basic ")
# ```
class FakeTransport < HetznerApi::HttpTransport
  record Request,
    method : String,
    url : String,
    headers : HTTP::Headers,
    body : String

  record Stub,
    method : String,
    url_pattern : Regex,
    status : Int32,
    body : String

  getter requests = [] of Request
  getter stubs = [] of Stub

  def stub(method : String, url_pattern : Regex, status : Int32, body : String) : Nil
    @stubs << Stub.new(method: method, url_pattern: url_pattern, status: status, body: body)
  end

  def request(method, url, headers, body) : {Int32, String}
    @requests << Request.new(method: method, url: url, headers: headers, body: body)

    match = @stubs.reverse.find { |s| s.method == method && s.url_pattern.matches?(url) }
    unless match
      raise "Aucun stub ne correspond à #{method} #{url} (stubs déclarés : " \
            "#{@stubs.map { |s| "#{s.method} #{s.url_pattern.source}" }.join(", ")})"
    end
    {match.status, match.body}
  end
end

# Fabrique un client Hetzner lié à un FakeTransport.
def build_client(
  transport : FakeTransport,
  username : String = "ws+test",
  password : String = "secret",
) : HetznerApi::Client
  HetznerApi::Client.new(
    username: username,
    password: password,
    transport: transport,
  )
end
