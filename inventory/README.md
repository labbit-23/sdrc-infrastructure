# Infrastructure inventory

Inventoried: [VPS1](vps1.md), [VPS2](vps2.md), the
[local devserver/application host](devserver.md), the
[sdrc-integrations workstation](sdrc-integrations.md) (Mirth, ERPNext,
Sysmex, ZK attendance, DICOM/MWL, DEXA), the
[Ctrl-S legacy Shivam server](ctrls-legacy-shivam.md), and an initial
[Orthanc/DICOM discovery record](orthanc-dicom.md).

Also recorded, from user-reported facts only (not yet inspected):
[lab-mirth](lab-mirth.md) (formerly `sdrc-h81`), the lab Mirth/analyser-bridge host that is powered
off outside lab hours.

Still required: legacy Oracle/LIMS, network/firewall/VPN, NVR/cameras, and
direct discovery of `lab-mirth` once it is powered on. Create one file per machine or managed service using
`templates/server.md`; do not put secrets in inventory files.
