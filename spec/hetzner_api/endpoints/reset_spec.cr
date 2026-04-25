require "../../spec_helper"

describe HetznerApi::Endpoints::Reset do
  describe "#types_for" do
    it "GET /reset/<n>, décode la liste des types disponibles" do
      transport = FakeTransport.new
      client = build_client(transport)
      transport.stub(
        "GET",
        /reset\/321/,
        status: 200,
        body: %({"reset":{"server_number":321,"type":["sw","hw","man"],"operating_status":"not_supported"}}),
      )

      types = client.reset.types_for(321)
      types.should contain(HetznerApi::Endpoints::ResetType::SW)
      types.should contain(HetznerApi::Endpoints::ResetType::HW)
      types.should contain(HetznerApi::Endpoints::ResetType::MAN)
    end
  end

  describe "#execute" do
    it "POST /reset/<n> avec type=hw par défaut" do
      transport = FakeTransport.new
      client = build_client(transport)
      transport.stub("POST", /reset\/321/, status: 200, body: "")

      client.reset.execute(server_number: 321)

      req = transport.requests.last
      req.method.should eq("POST")
      req.body.should eq("type=hw")
    end

    it "accepte type=sw / power / power_long" do
      transport = FakeTransport.new
      client = build_client(transport)
      transport.stub("POST", /reset/, status: 200, body: "")

      client.reset.execute(server_number: 321, type: HetznerApi::Endpoints::ResetType::PowerLong)

      transport.requests.last.body.should eq("type=power_long")
    end
  end

  describe "ResetType.from_api / to_api" do
    it "round-trip sur les valeurs supportées" do
      %w[sw hw man power power_long].each do |s|
        HetznerApi::Endpoints::ResetType.from_api(s).to_api.should eq(s)
      end
    end

    it "lève sur valeur inconnue" do
      expect_raises(ArgumentError, /inconnu/) do
        HetznerApi::Endpoints::ResetType.from_api("nuclear")
      end
    end
  end
end
