#!/usr/bin/env bash

# Nginx uninstaller
# Min. Requirement  : GNU/Linux Ubuntu 14.04
# Last Build        : 31/07/2019
# Author            : ESLabs.ID (eslabs.id@gmail.com)
# Since Version     : 1.0.0

# Include helper functions.
if [ "$(type -t run)" != "function" ]; then
    BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
    # shellchechk source=scripts/helper.sh
    # shellcheck disable=SC1090
    . "${BASEDIR}/helper.sh"
fi

# Make sure only root can run this installer script.
requires_root

# Remove nginx.
function init_nginx_removal() {
    # Stop nginx HTTP server process.
    if [[ $(pgrep -c nginx) -gt 0 ]]; then
        run service nginx stop
    fi

    # Remove nginx installation.
    if dpkg-query -l | awk '/nginx/ { print $2 }' | grep -qwE "^nginx-stable"; then
        echo "Nginx-common package found. Removing..."
        run apt-get -qq --purge remove -y nginx-stable
        if "${FORCE_REMOVE}"; then
            run add-apt-repository -y --remove ppa:nginx/stable
        fi
    elif dpkg-query -l | awk '/nginx/ { print $2 }' | grep -qwE "^nginx-custom"; then
        echo "Nginx-custom package found. Removing..."
        run apt-get -qq --purge remove -y nginx-custom
        if "${FORCE_REMOVE}"; then
            run add-apt-repository -y --remove ppa:rtcamp/nginx
        fi
    elif dpkg-query -l | awk '/nginx/ { print $2 }' | grep -qwE "^nginx-extras"; then
        echo "Nginx-stable package found. Removing..."
        run apt-get -qq --purge remove -y nginx-extras
        if "${FORCE_REMOVE}"; then
            run add-apt-repository -y --remove ppa:ondrej/nginx
        fi
    else
        echo "Nginx package not found. Possibly installed from source."

        NGINX_BIN=$(command -v nginx)

        echo "Nginx binary executable: ${NGINX_BIN}"

        if [[ -n "${NGINX_BIN}" ]]; then
            # Disable systemctl.
            if [ -f /etc/systemd/system/multi-user.target.wants/nginx.service ]; then
                echo "Disable Nginx service..."
                run systemctl disable nginx.service
            fi

            if [ -f /etc/systemd/system/multi-user.target.wants/nginx.service ]; then
                run unlink /etc/systemd/system/multi-user.target.wants/nginx.service
            fi

            if [ -f /lib/systemd/system/nginx.service ]; then
                run rm -f /lib/systemd/system/nginx.service
            fi

            # Remove binary executable file.
            if [ -f "${NGINX_BIN}" ]; then
                echo "Remove Nginx binary executable file..."
                run rm -f "${NGINX_BIN}"
            fi

            # Remove init file.
            if [ -f /etc/init.d/nginx ]; then
                run rm -f /etc/init.d/nginx
            fi

            if [ -d /usr/lib/nginx/ ]; then
                run rm -fr /usr/lib/nginx/
            fi

            if [ -d /etc/nginx/modules-enabled ]; then
                run rm -fr /etc/nginx/modules-enabled
            fi

            if [ -d /etc/nginx/modules-available ]; then
                run rm -fr /etc/nginx/modules-available
            fi

            # Delete default account from PageSpeed admin.
            if [ -f /srv/.htpasswd ]; then
                local USERNAME=${LEMPER_USERNAME:-"lemper"}
                #run echo "" > /srv/.htpasswd
                #run sed -i "/^lemper:/d" /srv/.htpasswd
                run sed -i "/^${USERNAME}:/d" /srv/.htpasswd
            fi
        fi
    fi

    # Remove nginx config files.
    warning "!! This action is not reversible !!"
    if "${AUTO_REMOVE}"; then
        REMOVE_NGXCONFIG="y"
    else
        while [[ "${REMOVE_NGXCONFIG}" != "y" && "${REMOVE_NGXCONFIG}" != "n" ]]; do
            read -rp "Remove all Nginx configuration files? [y/n]: " -e REMOVE_NGXCONFIG
        done
    fi

    if [[ "${REMOVE_NGXCONFIG}" == Y* || "${REMOVE_NGXCONFIG}" == y* || "${FORCE_REMOVE}" == true ]]; then
        run rm -fr /etc/nginx
        # Remove nginx-cache.
        run rm -fr /var/cache/nginx
        # Remove nginx html.
        run rm -fr /usr/share/nginx

        echo "All your Nginx configs files deleted permanently."
    fi
    
    # Final test.
    if "${DRYRUN}"; then
        warning "Nginx HTTP server removed in dryrun mode."
    else
        if [[ -z $(command -v nginx) ]]; then
            status "Nginx HTTP server removed succesfully."
        else
            warning "Unable to remove Nginx HTTP server."
        fi
    fi
}

echo "Uninstalling Nginx HTTP server..."
if [[ -n $(command -v nginx) || -x /usr/sbin/nginx ]]; then

    if "${AUTO_REMOVE}"; then
        REMOVE_NGINX="y"
    else
        while [[ "${REMOVE_NGINX}" != "y" && "${REMOVE_NGINX}" != "n" ]]; do
            read -rp "Are you sure to remove Nginx HTTP server? [y/n]: " -e REMOVE_NGINX
        done
    fi

    if [[ "${REMOVE_NGINX}" == Y* || "${REMOVE_NGINX}" == y* ]]; then
        init_nginx_removal "$@"
    else
        echo "Found NGiNX HTTP server, but not removed."
    fi
else
    warning "Oops, NGiNX installation not found."
fi
