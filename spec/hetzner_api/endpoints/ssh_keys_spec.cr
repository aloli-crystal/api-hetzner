require "../../spec_helper"

describe HetznerApi::Endpoints::SshKeys do
  describe "#list" do
    it "GET /key, décode le tableau" do
      transport = FakeTransport.new
      client = build_client(transport)
      transport.stub(
        "GET",
        /key$/,
        status: 200,
        body: %([{"key":{"name":"laptop","fingerprint":"aa:bb:cc","type":"ED25519","size":256,"data":"ssh-ed25519 AAAAC3..."}}]),
      )

      keys = client.ssh_keys.list
      keys.size.should eq(1)
      keys.first.name.should eq("laptop")
      keys.first.fingerprint.should eq("aa:bb:cc")
      keys.first.type.should eq("ED25519")
    end
  end

  describe "#create" do
    it "POST /key avec name + data en form-urlencoded" do
      transport = FakeTransport.new
      client = build_client(transport)
      transport.stub(
        "POST",
        /key$/,
        status: 201,
        body: %({"key":{"name":"laptop","fingerprint":"aa:bb:cc","type":"ED25519","size":256,"data":"ssh-ed25519 AAAAC3..."}}),
      )

      key = client.ssh_keys.create(name: "laptop", public_key: "ssh-ed25519 AAAAC3...")

      req = transport.requests.last
      req.method.should eq("POST")
      req.headers["Content-Type"].should eq("application/x-www-form-urlencoded")
      req.body.should contain("name=laptop")
      req.body.should contain("data=ssh-ed25519")
      key.name.should eq("laptop")
    end
  end

  describe "#delete" do
    it "DELETE /key/<fingerprint>" do
      transport = FakeTransport.new
      client = build_client(transport)
      transport.stub("DELETE", /key\/aa:bb:cc/, status: 200, body: "")

      client.ssh_keys.delete("aa:bb:cc")

      transport.requests.last.method.should eq("DELETE")
      transport.requests.last.url.should contain("/key/aa:bb:cc")
    end
  end

  describe "#ensure" do
    it "ne crée pas si une clé avec le même base64 existe déjà" do
      transport = FakeTransport.new
      client = build_client(transport)
      transport.stub(
        "GET",
        /key$/,
        status: 200,
        body: %([{"key":{"name":"existing","fingerprint":"aa:bb:cc","type":"ED25519","size":256,"data":"ssh-ed25519 AAAAC3xyz user@host"}}]),
      )

      key = client.ssh_keys.ensure(
        name: "ignored-name",
        public_key: "ssh-ed25519 AAAAC3xyz different-comment",
      )

      key.fingerprint.should eq("aa:bb:cc")
      key.name.should eq("existing")
      # Une seule requête (GET), pas de POST.
      transport.requests.size.should eq(1)
      transport.requests.first.method.should eq("GET")
    end

    it "crée la clé si aucune n'a le même base64" do
      transport = FakeTransport.new
      client = build_client(transport)
      transport.stub("GET", /key$/, status: 200, body: "[]")
      transport.stub(
        "POST",
        /key$/,
        status: 201,
        body: %({"key":{"name":"new","fingerprint":"dd:ee:ff","type":"ED25519","size":256,"data":"ssh-ed25519 AAAAnew user@host"}}),
      )

      key = client.ssh_keys.ensure(name: "new", public_key: "ssh-ed25519 AAAAnew user@host")
      key.name.should eq("new")
      key.fingerprint.should eq("dd:ee:ff")
      transport.requests.size.should eq(2)
      transport.requests.last.method.should eq("POST")
    end
  end
end
