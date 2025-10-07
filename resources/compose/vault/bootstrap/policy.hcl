# existing KV v2 reads
path "secret/data/msr"     { capabilities = ["read"] }
path "secret/metadata/msr" { capabilities = ["list","read"] }

# allow MSR to use the transit key
path "transit/encrypt/msr-key" { capabilities = ["update"] }
path "transit/decrypt/msr-key" { capabilities = ["update"] }
