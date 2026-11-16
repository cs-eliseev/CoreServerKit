#!/usr/bin/env bash

set -euo pipefail

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    source "${SCRIPT_DIR}/lib/common.sh"
    source "${SCRIPT_DIR}/lib/validation.sh"
    source "${SCRIPT_DIR}/lib/config.sh"
    source "${SCRIPT_DIR}/lib/security.sh"
    source "${SCRIPT_DIR}/lib/cert.sh"
fi

prompt_cert_domain() {
    local result_var="$1"
    local input_domain

    while true; do
        read -r -p "Enter domain (e.g. example.com): " input_domain

        if validate_domain "${input_domain}"; then
            break
        fi

        echo "Invalid domain. Expected format: example.com or sub.example.com"
        echo ""
    done

    printf -v "${result_var}" '%s' "${input_domain}"
    return 0
}

prompt_cert_email() {
    local result_var="$1"
    local input_email

    while true; do
        read -r -p "Email for Let's Encrypt expiry notices (Enter to skip): " input_email

        if [[ -z "${input_email}" ]] || validate_email "${input_email}"; then
            break
        fi

        echo "Invalid email address."
        echo ""
    done

    printf -v "${result_var}" '%s' "${input_email}"
    return 0
}

run_cert() {
    log_info "=== SSL Certificate (nginx + Let's Encrypt) ==="

    local domain="${CERT_DOMAIN:-}"
    local email="${CERT_EMAIL:-}"

    if [[ -n "${domain}" ]] && ! validate_domain "${domain}"; then
        die "Invalid CERT_DOMAIN: ${domain}"
    fi

    if [[ -n "${email}" ]] && ! validate_email "${email}"; then
        die "Invalid CERT_EMAIL: ${email}"
    fi

    if [[ -z "${domain}" ]]; then
        if [[ "${AUTO_MODE}" == true ]]; then
            log_warn "Auto mode: CERT_DOMAIN is not set, skipping SSL certificate"
            return 0
        fi
        echo ""
        prompt_cert_domain domain
    fi

    if is_cert_configured "${domain}"; then
        log_info "SSL certificate for ${domain} is already issued, skipping"
        return 0
    fi

    if ! check_domain_resolves "${domain}"; then
        log_warn "Domain ${domain} does not resolve in DNS, Let's Encrypt validation will likely fail"
        if [[ "${AUTO_MODE}" != true ]] && ! prompt_confirmation "Continue anyway?"; then
            log_info "SSL certificate cancelled"
            echo "Cancelled."
            return 0
        fi
    fi

    if [[ "${AUTO_MODE}" != true ]]; then
        if [[ -z "${CERT_EMAIL:-}" ]]; then
            prompt_cert_email email
        fi

        echo ""
        echo "=== SSL Certificate Configuration ==="
        echo "  Domain:       ${domain}"
        echo "  Email:        ${email:-none (no expiry notices)}"
        echo "  Web server:   nginx (HTTP -> HTTPS redirect, HTTP/2, HSTS)"
        echo "  Web root:     /var/www/${domain}"
        echo "  Firewall:     allow 443/tcp; 80/tcp opened only during validation"
        echo "  Auto-renewal: certbot timer"
        echo ""

        if ! prompt_confirmation "Issue certificate?"; then
            log_info "SSL certificate cancelled"
            echo "Cancelled."
            return 0
        fi
    fi

    log_info "--- nginx + certbot ---"
    install_cert_packages || die "Failed to install nginx/certbot"

    log_info "--- nginx site ---"
    create_temporary_certificate "${domain}" || die "Failed to create temporary certificate"
    configure_nginx_site "${domain}" || die "Failed to configure nginx site for ${domain}"
    reload_nginx || die "Failed to reload nginx"

    log_info "--- Firewall ---"
    allow_https_port || log_warn "Allow 443/tcp manually: ufw allow 443/tcp"
    install_certbot_port_hooks || die "Failed to install certbot hooks"

    log_info "--- Let's Encrypt ---"
    issue_letsencrypt_certificate "${domain}" "${email}" \
        || die "Failed to issue certificate for ${domain}, see ${LOG_FILE}"
    link_letsencrypt_certificate "${domain}" || die "Failed to link certificate for ${domain}"
    reload_nginx || die "Failed to reload nginx with the new certificate"

    local renewal="enabled (certbot timer)"
    if ! enable_certbot_renewal; then
        renewal="NOT configured, add 'certbot renew -q' to cron"
    fi

    log_change "SSL CERTIFICATE ISSUED: domain=${domain}, email=${email:-none}, renewal=${renewal}"

    echo ""
    echo "=== SSL Certificate Issued ==="
    echo "  Site:         https://${domain}"
    echo "  Certificate:  ${LETSENCRYPT_LIVE_DIR}/${domain}/"
    echo "  nginx config: $(get_nginx_site_config_path "${domain}")"
    echo "  Auto-renewal: ${renewal}"
    echo ""
    echo "  Check renewal: sudo certbot renew --dry-run"
    echo ""

    log_info "SSL certificate setup completed for ${domain}"
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_cert
fi
