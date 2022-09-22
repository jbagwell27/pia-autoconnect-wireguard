# PIA Wireguard Auto-Reconnect

Automatically regenerate a token and connect to PIA's Wireguard servers  
There are many people smarter than I who have probably figured out a better solution, but I was unable to find one online.  
This script combines bits and pieces of the [official scripts from PIA](https://github.com/pia-foss/manual-connections), and sets it up in a way that that allows you to hard code the values for automation.  

## Preface / Disclaimer

Since this is mostly PIA's code, It comes with the same warranty that they have, which is none. Use at your own risk.  
This only works with Wireguard and with port forwarding disabled. If you need those, you are welcome to modify this to your heart's content.  
I don't have a need for OpenVPN and I'm too lazy to add it will not work for that. Plus that process is simpler and doesn't require a renewed auth token.

## How it works

Since PIA's Wireguard tokens expire every 24 hours, if your constant connection is interrupted (power failure, update, etc) you won't be able to reconnect without generating a new token.  
This will do that for you. When set up correctly it will start a connection at boot, and refresh the entire config (and connection) every day keeping your token active.

Setting this up as a oneshot systemd service, it generates a token, and connects at startup. A cronjob then restarts that service every day, triggering the script to run again.

## Installation

### Environment

I am running this in a Debian 11 LXC container on top of Proxmox 7.2-7. The commands and system file paths may be different depending on your distribution.

### Dependencies

The requirements for this are exactly the same as PIA's official scripts. So that I'm not repeating them, you can see them [here](https://github.com/pia-foss/manual-connections#dependencies). This script, unlike the official ones, do not check for dependencies and will break if something is wrong.

### Steps

1. There are 3 variables that are required: `PREFERRED_REGION`, `PIA_USER`, and `PIA_PASS`.  
You can hard code them in the script (like I did), or reference them in a separate file.

    - **Hardcoding**:

        At the top of `auto-connect.sh` set the variables like so:

        ```ini
        PREFERRED_REGION=us_atlanta #From PIA's get_region.sh
        PIA_USER=p0123456
        PIA_PASS=xxx
        ```

    - **Using a file**:  
        In `PIA_VARS.info` have:

        ```ini
        PREFERRED_REGION=us_atlanta
        PIA_USER=p0123456
        PIA_PASS=xxx
        ```

        Then,

        At the top of `auto-connect.sh` you would have:

        ```sh
        source /path/to/PIA_VARS.info
        ```

2. Download and save the ca-cert from PIA's official repo.

    ```sh
    wget -O ca.rsa.4096.crt https://raw.githubusercontent.com/pia-foss/manual-connections/master/ca.rsa.4096.crt
    ```

3. Download/copy `auto-connect.sh` to a suitable location.

    ```sh
    wget -O auto-connect.sh https://raw.githubusercontent.com/jbagwell27/pia-autoconnect-wireguard/main/auto-connect.sh
    ```

4. Modify the script to accommodate your directory:

    On line 57 in `auto-connect.sh` change `/var/lib/pia/` to the direct path of the file:

    ```sh
        --cacert "/var/lib/pia/ca.rsa.4096.crt" \
    ```

5. Make a systemd service file: in `/etc/systemd/system/pia-connect.service`

    ```sh
    vim /etc/sytemd/system/pia-connect.service
    ```

    with the contents:

    ```service
    [Unit]
    Description=PIA-Wireguard Connection

    [Service]
    Type=oneshot
    ExecStart=/bin/bash /path/to/auto-connect.sh

    [Install]
    WantedBy=multi-user.target                          
    ```

6. Enable and start the service:

    ```sh
    sudo systemctl enable pia-connect.service && sudo systemctl start pia-connect.service
    ```

7. Test by checking your external IP:

    ```bash
    wget -qO - http://wtfismyip.com/text
    ```

8. Now we need to set it up so that it restarts every day to refresh the token. Edit the crontab:

    ```sh
    sudo crontab -e
    ```

    and add this to the top:

    ```cron
    @daily /usr/bin/systemctl restart pia-connect.service
    ```

    > Not all distros support `@daily` so you may need to use something like [https://crontab.guru/](https://crontab.guru/).

Success!