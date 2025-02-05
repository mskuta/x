from pyinfra import host
from pyinfra.facts.snap import SnapPackages
from pyinfra.operations import apt, snap

snap.package(
    name="Delete Snap packages",
    packages=[x for x in host.get_fact(SnapPackages) if x not in ("core", "snapd")],
    present=False,
)

apt.packages(
    name="Delete Snap daemon",
    packages=["snapd"],
    present=False,
    extra_uninstall_args="--autoremove --purge",
)

# vim: ts=4 sts=0 sw=4 et
