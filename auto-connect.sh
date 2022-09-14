#!/usr/bin/bash

# Fill in the informtion with your own information
PREFERRED_REGION=us_atlanta
PIA_USER=p0123456
PIA_PASS=xxx

# This only works with Wireguard with port forwarding disabled.
VPN_PROTOCOL=wireguard
PIA_PF="false"

selectedRegion=$PREFERRED_REGION

serverlist_url='https://serverlist.piaservers.net/vpninfo/servers/v6'

all_region_data=$(curl -s "$serverlist_url" | head -1)

get_selected_region_data() {
    regionData="$(echo "$all_region_data" |
        jq --arg REGION_ID "$selectedRegion" -r \
            '.regions[] | select(.id==$REGION_ID)')"
}

get_selected_region_data

WG_SERVER_IP=$(echo "$regionData" | jq -r '.servers.wg[0].ip')
WG_HOSTNAME=$(echo "$regionData" | jq -r '.servers.wg[0].cn')

timeout_timestamp() {
    date +"%c" --date='1 day' # Timestamp 24 hours
}

generateTokenResponse=$(curl -s --location --request POST \
    'https://www.privateinternetaccess.com/api/client/v2/token' \
    --form "username=$PIA_USER" \
    --form "password=$PIA_PASS")
token=$(echo "$generateTokenResponse" | jq -r '.token')
tokenExpiration=$(timeout_timestamp)
PIA_TOKEN=$token${nc}

export PIA_TOKEN

if [[ -f /proc/net/if_inet6 ]] &&
    [[ $(sysctl -n net.ipv6.conf.all.disable_ipv6) -ne 1 ||
    $(sysctl -n net.ipv6.conf.default.disable_ipv6) -ne 1 ]]; then

    sysctl -n net.ipv6.conf.all.disable_ipv6
    sysctl -n net.ipv6.conf.default.disable_ipv6
fi

privKey=$(wg genkey)
export privKey
pubKey=$(echo "$privKey" | wg pubkey)
export pubKey
wireguard_json="$(curl -s -G \
    --connect-to "$WG_HOSTNAME::$WG_SERVER_IP:" \
    --cacert "/var/lib/pia/ca.rsa.4096.crt" \
    --data-urlencode "pt=${PIA_TOKEN}" \
    --data-urlencode "pubkey=$pubKey" \
    "https://${WG_HOSTNAME}:1337/addKey")"

export wireguard_json

if [[ $(echo "$wireguard_json" | jq -r '.status') != "OK" ]]; then
    echo >&2 -e "Server did not return OK. Stopping now.${nc}"
    exit 1
fi

wg-quick down pia

dnsServer=$(echo "$wireguard_json" | jq -r '.dns_servers[0]')
dnsSettingForVPN="DNS = $dnsServer"

mkdir -p /etc/wireguard

echo "
[Interface]
Address = $(echo "$wireguard_json" | jq -r '.peer_ip')
PrivateKey = $privKey
$dnsSettingsForVPN
[Peer]
PersistentKeepalive = 25
PublicKey = $(echo "$wireguard_json" | jq -r '.server_key')
AllowedIPs = 0.0.0.0/0
Endpoint = ${WG_SERVER_IP}:$(echo "$wireguard_json" | jq -r '.server_port')
" >/etc/wireguard/pia.conf || exit 1

wg-quick up pia
