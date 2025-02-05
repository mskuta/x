from pyinfra.operations import systemd

systemd.service(
    name="Disable apt-daily",
    service="apt-daily.timer",
    running=False,
    enabled=False,
)

systemd.service(
    name="Disable apt-daily-upgrade",
    service="apt-daily-upgrade.timer",
    running=False,
    enabled=False,
)

# vim: ts=4 sts=0 sw=4 et
