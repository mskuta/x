from pyinfra.operations import apt, iptables, server

# specify LAN network IP address (with /mask), e.g. "10.10.10.0/24"
LAN = ""

apt.packages(
    name="Install packages",
    packages=["iptables", "iptables-persistent"],
    latest=True,
)

# drop invalid packets asap
iptables.rule(
    name="Customize table 'mangle'",
    chain="PREROUTING",
    jump="DROP",
    table="mangle",
    extras="-m conntrack --ctstate INVALID",
)

# accept everything coming through the loopback interface
iptables.rule(
    name="Customize default table (I)",
    chain="INPUT",
    jump="ACCEPT",
    in_interface="lo",
)

# accept everything coming through already established connections
iptables.rule(
    name="Customize default table (II)",
    chain="INPUT",
    jump="ACCEPT",
    extras="-m conntrack --ctstate ESTABLISHED,RELATED",
)

# accept connections originating from the local network
iptables.rule(
    name="Customize default table (III)",
    chain="INPUT",
    jump="ACCEPT",
    extras=" ".join(("-m conntrack --ctstate NEW", "-m comment --comment LAN")),
    source=LAN,
)

iptables.chain(
    name="Set policy for chain FORWARD",
    chain="FORWARD",
    policy="DROP",
)

iptables.chain(
    name="Set policy for chain INPUT",
    chain="INPUT",
    policy="DROP",
)

iptables.chain(
    name="Set policy for chain OUTPUT",
    chain="OUTPUT",
    policy="ACCEPT",
)

server.shell(
    name="Persist rules",
    commands=["/usr/sbin/netfilter-persistent save"],
)

# vim: ts=4 sts=0 sw=4 et
