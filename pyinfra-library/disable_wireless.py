from pyinfra.operations import files, systemd

files.line(
    name="Modify config.txt",
    path="/boot/firmware/config.txt",
    line="dtoverlay=disable-bt",
)

for service in ("bluetooth.service", "hciuart.service", "wpa_supplicant.service"):
    systemd.service(
        name=f"Disable {service}",
        service=service,
        running=False,
        enabled=False,
    )

# vim: ts=4 sts=0 sw=4 et
