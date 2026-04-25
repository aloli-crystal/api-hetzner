require "../../spec_helper"

describe HetznerApi::Endpoints::Boot do
  describe "#activate_rescue" do
    it "POST /boot/<n>/rescue avec os=linux et un seul authorized_key" do
      transport = FakeTransport.new
      client = build_client(transport)
      transport.stub(
        "POST",
        /boot\/321\/rescue/,
        status: 200,
        body: %({"rescue":{"server_number":321,"os":"linux","active":true,"password":"jEt0dtUvomlyOwRr","authorized_key":["aa:bb:cc"],"host_key":[]}}),
      )

      cfg = client.boot.activate_rescue(server_number: 321, authorized_keys: ["aa:bb:cc"])
      cfg.active.should be_true
      cfg.password.should eq("jEt0dtUvomlyOwRr")
      cfg.authorized_key.should eq(["aa:bb:cc"])

      req = transport.requests.last
      req.body.should contain("os=linux")
      # Format Hetzner array : authorized_key%5B%5D=...
      req.body.should contain("authorized_key%5B%5D=aa%3Abb%3Acc")
    end

    it "POST avec plusieurs authorized_key, sérialise chaque entrée séparément" do
      transport = FakeTransport.new
      client = build_client(transport)
      transport.stub(
        "POST",
        /boot\/321\/rescue/,
        status: 200,
        body: %({"rescue":{"server_number":321,"os":"linux","active":true,"authorized_key":["aa:bb","cc:dd"],"host_key":[]}}),
      )

      client.boot.activate_rescue(server_number: 321, authorized_keys: ["aa:bb", "cc:dd"])

      req = transport.requests.last
      # Deux entrées multi-valued en form-urlencoded
      req.body.scan("authorized_key%5B%5D=").size.should eq(2)
      req.body.should contain("authorized_key%5B%5D=aa%3Abb")
      req.body.should contain("authorized_key%5B%5D=cc%3Add")
    end

    it "POST sans authorized_key (password root généré seulement)" do
      transport = FakeTransport.new
      client = build_client(transport)
      transport.stub(
        "POST",
        /rescue/,
        status: 200,
        body: %({"rescue":{"server_number":321,"os":"linux","active":true,"password":"abcd1234","authorized_key":[],"host_key":[]}}),
      )

      cfg = client.boot.activate_rescue(server_number: 321)
      cfg.password.should eq("abcd1234")
      cfg.authorized_key.should be_empty

      req = transport.requests.last
      req.body.should contain("os=linux")
      req.body.should_not contain("authorized_key")
    end
  end

  describe "#rescue_status" do
    it "GET /boot/<n>/rescue, décode active=false quand pas activé" do
      transport = FakeTransport.new
      client = build_client(transport)
      transport.stub(
        "GET",
        /boot\/321\/rescue/,
        status: 200,
        body: %({"rescue":{"server_number":321,"os":null,"active":false,"password":null,"authorized_key":[],"host_key":[]}}),
      )

      cfg = client.boot.rescue_status(321)
      cfg.active.should be_false
      cfg.os.should be_nil
    end
  end

  describe "#deactivate_rescue" do
    it "DELETE /boot/<n>/rescue" do
      transport = FakeTransport.new
      client = build_client(transport)
      transport.stub("DELETE", /rescue/, status: 200, body: "")

      client.boot.deactivate_rescue(321)

      transport.requests.last.method.should eq("DELETE")
      transport.requests.last.url.should contain("/boot/321/rescue")
    end
  end
end
