# SPDX-License-Identifier: PMPL-1.0 OR PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2024-2025 hyperpolymath
#
# Minimal Docker image to serve well-known resources
# Usage: docker build -t well-known-server .
#        docker run -p 8080:80 well-known-server

FROM nginx:alpine

# Copy well-known files
COPY .well-known/ /usr/share/nginx/html/.well-known/

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost/.well-known/security.txt || exit 1

EXPOSE 80
