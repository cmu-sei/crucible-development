# Custom Certificates

Place PEM-encoded root CA certificates in this directory with a `.crt` extension before rebuilding the dev container image. Every `.crt` file here is copied into the container and trusted automatically via `update-ca-certificates`; all other file types are ignored.

If you rely on Zscaler (or another SSL inspection solution), copy the issued root certificate into this folder as `*.crt`, rebuild, and the container will trust outbound TLS through that proxy.

**Important - Crucible Certificate Usage**

Any Crucible root CA certificate placed in this directory is intended **strictly for local development and testing purporses only**.
