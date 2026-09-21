# Service relationships

```text
Internet users -> DNS/TLS -> VPS1 nginx -> Next.js/apps/APIs/workers/Jasper
                                         -> VPS2 Supabase gateway/services
                                             -> PostgreSQL bind-mounted data

Local modalities -> Orthanc/DICOM -> Mirth/integration -> LIMS/Labit/reporting
                       [all local links and routes TODO: VERIFY]
```

Document protocol, port, authentication mechanism name, failure impact, owner,
and validation check for every edge. Do not record credential values.
