
Debugging Cloud-init
====================
The most fragile part of setup is generally the first-run setup script implemented as a cloud-init user-init file.  Debugging it requires some special sauce:

make it like we never did cloud-init
`sudo cloud-init clean --logs`

