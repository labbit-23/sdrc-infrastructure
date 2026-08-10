# Labit machine API proxy

The machine middleware is an outbound client. It does not need an inbound
listener or callback route on the Mirth host.

Nginx terminates HTTPS on the existing `labit.sdrc.in:443` virtual host and
forwards only these paths to Core's loopback listener:

```text
GET  https://labit.sdrc.in/machine-api/orders/{barcode}
POST https://labit.sdrc.in/machine-api/inbox
```

Internal framework destinations:

```text
GET  http://127.0.0.1:8001/api/framework/machine_order_lookup?barcode={barcode}
POST http://127.0.0.1:8001/api/framework/machine_result_ingest
```

The proxy preserves `X-Api-Key-Id` and `X-Api-Secret`. It forwards no other
Core routes under `/machine-api`; order lookup is GET-only and inbox submission
is POST-only.

The source template is `deploy/nginx/labit-ui`. Deploy it only after checking
the existing certificate paths and running:

```bash
nginx -t
systemctl reload nginx
```

The Mirth host only needs outbound HTTPS access to `labit.sdrc.in`. Its
Tailscale address is not part of this contract.
