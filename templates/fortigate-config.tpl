Content-Type: multipart/mixed; boundary="==FGTCONF=="
MIME-Version: 1.0

--==FGTCONF==
Content-Type: text/plain; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="config"

config system global
    set admin-sport ${admin_port}
    set hostname "fgt-nsi-$${HOSTNAME}"
    set admintimeout 60
end

config system admin
    edit "admin"
        set password ${admin_pass}
    next
end

config system sdn-connector
    edit "gcp"
        set type gcp
    next
end

config system interface
    edit port1
        set mode static
        set ip 0.0.0.0/0
        set allowaccess ping
    next
    edit port2
        set mode static  
        set ip 0.0.0.0/0
        set allowaccess https ssh ping
    next
end

# Health check configuration
config system probe-response
    set mode http-probe
    set http-probe-value OK
    set port 8080
end

# Basic firewall policy for NSI traffic
config firewall policy
    edit 1
        set name "nsi-inspection"
        set srcintf "port1"
        set dstintf "port1"
        set action accept
        set srcaddr "all"
        set dstaddr "all"
        set schedule "always"
        set service "ALL"
        set comments "NSI traffic inspection"
        set inspection-mode flow
        set utm-status enable
    next
end

--==FGTCONF==--