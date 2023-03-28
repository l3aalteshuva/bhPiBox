
Debugging Cloud-init
====================
The most fragile part of setup is generally the first-run setup script implemented as a cloud-init user-init file.  Debugging it requires some special sauce:

make it like we never did cloud-init
`sudo cloud-init clean --logs`

https://stackoverflow.com/questions/23065673/how-to-re-run-cloud-init-without-reboot
```
Detect local datasource (cloud platform):

sudo cloud-init init --local

Detect any datasources which require network up and run "cloud_init_modules" defined in /etc/cloud/cloud.cfg:

sudo cloud-init init

Run all cloud_config_modules defined in /etc/cloud/cloud.cfg:

sudo cloud-init modules --mode=config

Run all cloud_final_modules defined in /etc/cloud/cloud.cfg: sudo cloud-init modules --mode=final
```
