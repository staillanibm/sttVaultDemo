pid_file = "/vault/agent.pid"

vault {
  address = "http://vault:8200"
  retry {
    num_retries = 3
  }
}

auto_auth {
  method "approle" {
    mount_path = "auth/approle"
    config = {
      role_id_file_path                = "/tmp/vault/role_id"
      secret_id_file_path              = "/tmp/vault/secret_id"   
      remove_secret_id_file_after_reading = true
    }
  }

  sink "file" {
    config = {
      path = "/tmp/vault-token/token"          
    }
  }
}
