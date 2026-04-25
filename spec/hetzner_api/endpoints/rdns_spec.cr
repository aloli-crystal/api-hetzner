require "../../spec_helper"

describe HetznerApi::Endpoints::Rdns do
  describe "#list" do
    it "GET /rdns, décode tableau de {\"rdns\":{...}}" do
      transport = FakeTransport.new
      client = build_client(transport)
      transport.stub(
        "GET",
        /rdns$/,
        status: 200,
        body: %([{"rdns":{"ip":"1.2.3.4","ptr":"web01.aloli.fr"}},{"rdns":{"ip":"5.6.7.8","ptr":"db01.aloli.fr"}}]),
      )

      records = client.rdns.list
      records.size.should eq(2)
      records.first.ip.should eq("1.2.3.4")
      records.first.ptr.should eq("web01.aloli.fr")
    end
  end

  describe "#get" do
    it "GET /rdns/<ip>" do
      transport = FakeTransport.new
      client = build_client(transport)
      transport.stub(
        "GET",
        /rdns\/1\.2\.3\.4/,
        status: 200,
        body: %({"rdns":{"ip":"1.2.3.4","ptr":"web01.aloli.fr"}}),
      )

      record = client.rdns.get("1.2.3.4")
      record.ip.should eq("1.2.3.4")
      record.ptr.should eq("web01.aloli.fr")
    end

    it "lève NotFound si l'IP n'a pas de PTR" do
      transport = FakeTransport.new
      client = build_client(transport)
      transport.stub(
        "GET",
        /rdns/,
        status: 404,
        body: %({"error":{"status":404,"code":"IP_NOT_FOUND","message":"IP not found"}}),
      )

      expect_raises(HetznerApi::NotFound) do
        client.rdns.get("99.99.99.99")
      end
    end
  end

  describe "#set" do
    it "POST /rdns/<ip> avec ptr (upsert idempotent)" do
      transport = FakeTransport.new
      client = build_client(transport)
      transport.stub(
        "POST",
        /rdns\/1\.2\.3\.4/,
        status: 200,
        body: %({"rdns":{"ip":"1.2.3.4","ptr":"web01.aloli.fr"}}),
      )

      record = client.rdns.set(ip: "1.2.3.4", ptr: "web01.aloli.fr")
      record.ptr.should eq("web01.aloli.fr")

      req = transport.requests.last
      req.method.should eq("POST")
      req.body.should contain("ptr=web01.aloli.fr")
    end
  end

  describe "#delete" do
    it "DELETE /rdns/<ip>" do
      transport = FakeTransport.new
      client = build_client(transport)
      transport.stub("DELETE", /rdns\/1\.2\.3\.4/, status: 200, body: "")

      client.rdns.delete("1.2.3.4")

      transport.requests.last.method.should eq("DELETE")
    end
  end
end
