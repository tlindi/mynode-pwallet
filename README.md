 MyNodeBTC Marketplace Community App from https://github.com/Hodladi/pWallet2.0

./dist contains .tar.gz to be uploaded

NO WARRANTIES OF ANY KIND!

**TAKE, KEEP AND VERIFY BACKUP DATA RESTORABILITY BY YOURSELF!**
* Even install and uninstall do and restore backups,
  and fund are not on pWallet but phonixd.
---

### ToDo
- [X] nothing

### pWallet version
* v2.1.0A (v9) - Fixed uninstall and changed docker build name

### pWallet version
* v2.1.0 (v9)

### Backup & Restore
* App uninstall creates appsettings.json, database and LNURL folder backup and
* during (re)install they are restored, if existing backup is found.

### Installation and startup fixes
* Installation done only if phoenixd configuration is found.
* Starts only after phoenixd service.

### Install time variable setting
* make sed to end of line from "ApiPassword" always cause "SET BY USER" might have been "nulled" previous faulty run
