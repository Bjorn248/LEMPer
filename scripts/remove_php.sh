#!/usr/bin/env bash

# PHP & FPM Uninstaller
# Min. Requirement  : GNU/Linux Ubuntu 14.04
# Last Build        : 12/07/2019
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

function remove_php_fpm() {
    # PHP version.
    local PHPv="${1}"
    if [ -z "${PHPv}" ]; then
        PHPv=${PHP_VERSION:-"7.3"}
    fi

    # Related PHP packages to be removed.
    local PHP_PKGS=()

    # Stop default PHP FPM process.
    if [[ $(pgrep -c "php-fpm${PHPv}") -gt 0 ]]; then
        run service "php${PHPv}-fpm" stop
    fi

    if [[ -n $(command -v "php${PHPv}") ]]; then
        # Installed PHP Packages.
        PHP_PKGS=("php${PHPv} php${PHPv}-bcmath php${PHPv}-cli php${PHPv}-common \
php${PHPv}-curl php${PHPv}-dev php${PHPv}-fpm php${PHPv}-mysql php${PHPv}-gd \
php${PHPv}-gmp php${PHPv}-imap php${PHPv}-intl php${PHPv}-json php${PHPv}-ldap \
php${PHPv}-mbstring php${PHPv}-opcache php${PHPv}-pspell php${PHPv}-readline \
php${PHPv}-recode php${PHPv}-snmp php${PHPv}-soap php${PHPv}-sqlite3 \
php${PHPv}-tidy php${PHPv}-xml php${PHPv}-xmlrpc php${PHPv}-xsl php${PHPv}-zip" "${PHP_PKGS[@]}")

        if [[ "${PHPv//.}" -lt "72" ]]; then
            if "php${PHPv}" -m | grep -qw "mcrypt"; then
                #run apt-get --purge remove -y php${PHPv}-mcrypt
                PHP_PKGS=("php${PHPv}-mcrypt" "${PHP_PKGS[@]}")
            fi
        elif [[ "${PHPv}" == "7.2" ]]; then
            if "php${PHPv}" -m | grep -qw "mcrypt"; then
                # Uninstall mcrypt pecl.
                run pecl uninstall mcrypt-1.0.1

                # Unlink eabled module.
                if [ -f "/etc/php/${PHPv}/cli/conf.d/20-mcrypt.ini" ]; then
                    run unlink "/etc/php/${PHPv}/cli/conf.d/20-mcrypt.ini"
                fi

                if [ -f "/etc/php/${PHPv}/fpm/conf.d/20-mcrypt.ini" ]; then
                    run unlink "/etc/php/${PHPv}/fpm/conf.d/20-mcrypt.ini"
                fi

                # Remove module.
                run rm -f "/etc/php/${PHPv}/mods-available/mcrypt.ini"
            fi
        else
            # Use libsodium? remove separately.
            warning "If you're installing Libsodium extension, then remove it separately."
        fi
    
        if [[ "${#PHP_PKGS[@]}" -gt 0 ]]; then
            echo "Removing PHP${PHPv} & FPM packages..."
            # shellcheck disable=SC2068
            run apt-get -qq --purge remove -y ${PHP_PKGS[@]}
        fi

        # Remove PHP & FPM config files.
        warning "!! This action is not reversible !!"

        if "${AUTO_REMOVE}"; then
            REMOVE_PHPCONFIG="y"
        else
            while [[ "${REMOVE_PHPCONFIG}" != "y" && "${REMOVE_PHPCONFIG}" != "n" ]]; do
                read -rp "Remove PHP${PHPv} & FPM configuration files? [y/n]: " -i n -e REMOVE_PHPCONFIG
            done
        fi

        if [[ "${REMOVE_PHPCONFIG}" == Y* || "${REMOVE_PHPCONFIG}" == y* || "${FORCE_REMOVE}" == true ]]; then
            if [ -d "/etc/php/${PHPv}" ]; then
                run rm -fr "/etc/php/${PHPv}"
            fi

            echo "All your configuration files deleted permanently."
        fi

        if [[ -z $(command -v "php${PHPv}") ]]; then
            status "PHP${PHPv} & FPM installation removed."
        else
            warning "Unable to remove PHP${PHPv} & FPM installation."
        fi
    else
        warning "PHP${PHPv} & FPM installation not found."
    fi   
}

# Remove PHP & FPM.
function init_php_fpm_removal() {
    # PHP version.
    local PHPv="${1}"
    if [[ -z "${PHPv}" || "${PHPv}" =~ *install || "${PHPv}" == *remove ]]; then
        PHPv=${PHP_VERSION:-"7.3"}
    fi

    case "${PHPv}" in
        "5.6")
            remove_php_fpm "5.6"
        ;;
        "7.0")
            remove_php_fpm "7.0"
        ;;
        "7.1")
            remove_php_fpm "7.1"
        ;;
        "7.2")
            remove_php_fpm "7.2"
        ;;
        "7.3")
            remove_php_fpm "7.3"
        ;;
        "all")
            remove_php_fpm "5.6"
            remove_php_fpm "7.0"
            remove_php_fpm "7.1"
            remove_php_fpm "7.2"
            remove_php_fpm "7.3"
        ;;
        *)
            fail "Invalid argument: ${PHPv}"
            exit 1
        ;;
    esac

    # Final clean up.
    if "${DRYRUN}"; then
        warning "PHP${PHPv} & FPM removed in dryrun mode."
    else
        if [[ -z $(command -v php5.6) && \
            -z $(command -v php7.0) && \
            -z $(command -v php7.1) && \
            -z $(command -v php7.2) && \
            -z $(command -v php7.3) ]]; then

            # Remove PHP repository.
            run add-apt-repository -y --remove ppa:ondrej/php

            # Remove all the rest PHP lib files.
            if [[ -d /usr/lib/php ]]; then
                run rm -fr /usr/lib/php
            fi

            echo "All PHP-FPM installation completely removed."
        fi
    fi
}

echo "Uninstalling PHP & FPM..."
if [[ -n $(command -v php5.6) || \
    -n $(command -v php7.0) || \
    -n $(command -v php7.1) || \
    -n $(command -v php7.2) || \
    -n $(command -v php7.3) ]]; then

    if "${AUTO_REMOVE}"; then
        REMOVE_PHP="y"
    else
        while [[ "${REMOVE_PHP}" != "y" && "${REMOVE_PHP}" != "n" ]]; do
            read -rp "Are you sure to remove PHP & FPM? [y/n]: " -e REMOVE_PHP
        done
    fi

    if [[ "${REMOVE_PHP}" == Y* || "${REMOVE_PHP}" == y* ]]; then
        init_php_fpm_removal "$@"
    else
        echo "Found PHP & FPM, but not removed."
    fi
else
    warning "Oops, PHP & FPM installation not found."
fi
