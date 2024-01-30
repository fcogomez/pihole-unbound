FROM pihole/pihole:latest
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install unbound -y

RUN apt-get install wget -y
RUN apt-get install dnsutils -y
RUN apt-get install nano -y

RUN tee /etc/unbound/unbound.conf.d/pi-hole.conf <<EOF
server:
    # If no logfile is specified, syslog is used
    # logfile: "/var/log/unbound/unbound.log"
    verbosity: 0

    interface: 127.0.0.1
    port: 5335
    do-ip4: yes
    do-udp: yes
    do-tcp: yes

    # May be set to yes if you have IPv6 connectivity
    do-ip6: no

    # You want to leave this to no unless you have *native* IPv6. With 6to4 and
    # Terredo tunnels your web browser should favor IPv4 for the same reasons
    prefer-ip6: no

    log-queries: no
    hide-version: yes
    hide-identity: yes
    identity: "DNS"

    # Use this only when you downloaded the list of primary root servers!
    # If you use the default dns-root-data package, unbound will find it automatically
    root-hints: "/var/lib/unbound/root.hints"

    # Trust glue only if it is within the server's authority
    harden-glue: yes
    harden-algo-downgrade: yes
    harden-short-bufsize: yes
    harden-large-queries: yes
    harden-dnssec-stripped: yes
    harden-below-nxdomain: yes
    harden-referral-path: no
    do-not-query-localhost: no

    # Require DNSSEC data for trust-anchored zones, if such data is absent, the zone becomes BOGUS
    harden-dnssec-stripped: yes

    # Don't use Capitalization randomization as it known to cause DNSSEC issues sometimes
    # see https://discourse.pi-hole.net/t/unbound-stubby-or-dnscrypt-proxy/9378 for further details
    use-caps-for-id: no

    # Reduce EDNS reassembly buffer size.
    # Suggested by the unbound man page to reduce fragmentation reassembly problems
    edns-buffer-size: 1472

    # Perform prefetching of close to expired message cache entries
    # This only applies to domains that have been frequently queried
    prefetch: yes
    prefetch-key: yes
    qname-minimisation: yes
    aggressive-nsec: yes
    ratelimit: 1000
    rrset-roundrobin: yes
    minimal-responses: yes
    num-queries-per-thread: 4096
    outgoing-range: 8192
    serve-expired: yes
    unwanted-reply-threshold: 10000
    val-clean-additional: yes

    # One thread should be sufficient, can be increased on beefy machines. In reality for most users running on small networks or on a single machine, it should be unnecessary to seek performance enhancement by increasing num-threads above 1.
    num-threads: 3

    # Ensure kernel buffer is large enough to not lose messages in traffic spikes
    so-rcvbuf: 1m

    # Ensure privacy of local IP ranges
    private-address: 192.168.0.0/16
    private-address: 169.254.0.0/16
    private-address: 172.16.0.0/12
    private-address: 10.0.0.0/8
    private-address: fd00::/8
    private-address: fe80::/10
    private-address: ::ffff:0:0/96

    remote-control:
        control-enable: no
EOF

RUN wget https://www.internic.net/domain/named.root -qO- | sudo tee /var/lib/unbound/root.hints
RUN touch /etc/s6-overlay/s6-rc.d/user/contents.d/unbound
RUN mkdir /etc/s6-overlay/s6-rc.d/unbound
RUN echo oneshot | tee /etc/s6-overlay/s6-rc.d/unbound/type
RUN tee /etc/s6-overlay/s6-rc.d/unbound/up <<EOF
foreground { echo "starting unbound..." }
/etc/init.d/unbound start
EOF
