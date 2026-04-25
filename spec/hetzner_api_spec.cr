require "./spec_helper"

describe HetznerApi do
  it "expose une version" do
    HetznerApi::VERSION.should eq("0.1.0")
  end
end

describe HetznerApi::Client do
  describe "auth HTTP Basic" do
    it "construit l'en-tête Authorization correctement" do
      transport = FakeTransport.new
      transport.stub("GET", /key/, status: 200, body: "[]")

      client = build_client(transport, username: "ws+test", password: "secret123")
      client.ssh_keys.list

      header = transport.requests.last.headers["Authorization"]
      header.should start_with("Basic ")
      # Décode pour vérifier
      decoded = Base64.decode_string(header.lchop("Basic "))
      decoded.should eq("ws+test:secret123")
    end

    it "lève AuthenticationError sur HTTP 401" do
      transport = FakeTransport.new
      transport.stub("GET", /key/, status: 401, body: %({"error":{"status":401,"code":"UNAUTHORIZED","message":"Authentication failed"}}))

      client = build_client(transport)
      expect_raises(HetznerApi::AuthenticationError) do
        client.ssh_keys.list
      end
    end

    it "lève RateLimited sur HTTP 403 + RATE_LIMIT_EXCEEDED" do
      transport = FakeTransport.new
      transport.stub("POST", /reset/, status: 403, body: %({"error":{"status":403,"code":"RATE_LIMIT_EXCEEDED","message":"limit exceeded","max_request":50,"interval":3600}}))

      client = build_client(transport)
      ex = expect_raises(HetznerApi::RateLimited) do
        client.reset.execute(server_number: 321)
      end
      ex.max_request.should eq(50)
      ex.interval.should eq(3600)
    end

    it "lève NotFound sur HTTP 404" do
      transport = FakeTransport.new
      transport.stub("GET", /server\/999/, status: 404, body: %({"error":{"status":404,"code":"SERVER_NOT_FOUND","message":"Server not found"}}))

      client = build_client(transport)
      expect_raises(HetznerApi::NotFound) do
        client.servers.get(999)
      end
    end

    it "lève Conflict sur HTTP 409 (KEY_ALREADY_EXISTS)" do
      transport = FakeTransport.new
      transport.stub("POST", /key/, status: 409, body: %({"error":{"status":409,"code":"KEY_ALREADY_EXISTS","message":"Key already exists"}}))

      client = build_client(transport)
      expect_raises(HetznerApi::Conflict) do
        client.ssh_keys.create(name: "test", public_key: "ssh-ed25519 AAAA...")
      end
    end

    it "lève MaintenanceMode sur HTTP 503" do
      transport = FakeTransport.new
      transport.stub("GET", /server/, status: 503, body: %({"error":{"status":503,"code":"MAINTENANCE","message":"Service in maintenance"}}))

      client = build_client(transport)
      expect_raises(HetznerApi::MaintenanceMode) do
        client.servers.list
      end
    end
  end
end
