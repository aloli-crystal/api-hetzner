require "../../spec_helper"

describe HetznerApi::Endpoints::Servers do
  describe "#list" do
    it "GET /server, décode le tableau de {\"server\":{...}}" do
      transport = FakeTransport.new
      client = build_client(transport)
      transport.stub(
        "GET",
        /server$/,
        status: 200,
        body: %([
          {"server":{"server_ip":"123.123.123.123","server_ipv6_net":"2a01:f48:111:4221::","server_number":321,"server_name":"web01","product":"AX52","dc":"FSN1-DC22","status":"ready"}},
          {"server":{"server_ip":"5.6.7.8","server_number":322,"server_name":"db01","product":"EX44"}}
        ]),
      )

      servers = client.servers.list
      servers.size.should eq(2)
      servers.first.server_number.should eq(321)
      servers.first.server_ip.should eq("123.123.123.123")
      servers.first.product.should eq("AX52")
      servers.last.server_name.should eq("db01")
    end

    it "retourne tableau vide si l'API renvoie []" do
      transport = FakeTransport.new
      client = build_client(transport)
      transport.stub("GET", /server/, status: 200, body: "[]")

      client.servers.list.should be_empty
    end
  end

  describe "#get" do
    it "GET /server/<n>, décode {\"server\":{...}}" do
      transport = FakeTransport.new
      client = build_client(transport)
      transport.stub(
        "GET",
        /server\/321/,
        status: 200,
        body: %({"server":{"server_number":321,"server_ip":"1.2.3.4","product":"AX52","dc":"FSN1-DC22"}}),
      )

      server = client.servers.get(321)
      server.server_number.should eq(321)
      server.server_ip.should eq("1.2.3.4")
      server.dc.should eq("FSN1-DC22")
    end
  end
end
