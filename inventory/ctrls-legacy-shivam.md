# Ctrl-S legacy Shivam server

Last reviewed: 21 September 2026
Status: migration/decommission candidate; do not cancel until residual clients
are redirected and a final backup is validated.

## Identity and capacity

- Public address: `120.138.8.37`
- Hostname: `SDRC-THE18813RB`
- Provider/location: Ctrl-S, Hyderabad (provider details/SLA TODO: VERIFY)
- Platform: Xen HVM virtual machine; dedicated physical hardware is not evidenced
- OS: Windows Server 2016 Standard, build 14393
- Resources: 4 logical CPUs, 12 GB RAM, approximately 300 GB system disk
- Capacity observed: approximately 0.7 GB free RAM and 11.1 GB free disk

## Legacy stack

- Oracle 11g SID `NEOSOFT`, listener on TCP 1521
- Tomcat 7 / Java 8, locally on TCP 19999
- Tomcat 9 / Java 8, locally on TCP 17777
- nginx exposes/proxies TCP 9999 and 7777
- iReport 5.5 / Java 7 was running during discovery
- FileZilla FTP, Dropbox, Google Drive and Zabbix were also running

Important data/application paths include:

```text
C:\app\Administrator\oradata\neosoft
C:\app\Administrator\flash_recovery_area\neosoft
C:\tomcat7\tomcat
C:\tomcat9
C:\nginx
C:\DB
```

Oracle and application ports must not be assumed safely restricted; firewall
and provider ACL exposure remain TODO: VERIFY.

## Observed residual usage

The replacement platform has taken over most traffic, but the legacy server was
still receiving requests on 20–21 September 2026. Sanitized access-log analysis
found three remaining categories:

1. Patient/MD Android application requests for login, notifications, dashboard,
   themes and form saves.
2. Browser-based MD workflows using diagnostic requisitions, requisition
   autofill, client login and record search.
3. Automated Node and Python clients calling `/clouduat/TApiQuery`.

Principal legacy endpoints include:

```text
/shivam/TDGRequisitions
/shivam/Dg/TDGRequisitionAutofill.jsp
/shivam/ClientLoginLoad.jsp
/shivam/searchRecords
/shivam/PacsCheck
/clouduat/TApiQuery
```

Repository searches also found direct address references in `labit-py`, the
SDRC website, archived report-delivery code, Shivam migration tooling and Mirth
channel exports. A repository reference alone does not prove a live dependency;
runtime configuration and active Mirth channels must be checked.

## Backup risk

The discovered scheduled `DB Backup` task executes
`C:\DB\Batch\DiagBackupRAR.bat`. The newest obvious archive found during the
review was dated 19 July 2026, and many backup logs were zero bytes. No current,
off-site, restore-tested Oracle backup was evidenced. The database, Tomcat apps,
Jasper/iReport templates, images/documents and nginx configuration require a
fresh encrypted backup before shutdown.

## Decommission gate

1. Redirect/update Patient App, MD apps, Node/Python `TApiQuery` clients and any
   active Mirth channels.
2. Verify replacement parity for the listed endpoints and report/image access.
3. Produce and restore-test final Oracle and filesystem backups.
4. Stop nginx/Tomcat/Oracle during an announced observation window without
   deleting the VM.
5. Observe for at least seven days and resolve every reported dependency.
6. Preserve the final encrypted archive, then cancel the subscription.

Decision: do not rebuild or promote this VM. Complete residual migration and
cancel the approximately USD 100/month subscription.
