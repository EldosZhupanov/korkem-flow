FROM node:24-bookworm AS node-src

FROM python:3.14-slim-bookworm

ARG WKHTMLTOPDF_VERSION=0.12.6.1-3

RUN apt-get update && apt-get install -y --no-install-recommends \
      curl git wget gpg gcc build-essential pkg-config \
      mariadb-client libmariadb-dev \
      redis-tools \
      libffi-dev libssl-dev libbz2-dev \
      libpango-1.0-0 libharfbuzz0b libpangoft2-1.0-0 libpangocairo-1.0-0 \
    && wget -q -O /tmp/wkhtmltox.deb \
      "https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_${WKHTMLTOPDF_VERSION}.bookworm_amd64.deb" \
    && apt-get install -y /tmp/wkhtmltox.deb \
    && rm /tmp/wkhtmltox.deb \
    && rm -rf /var/lib/apt/lists/*

COPY --from=node-src /usr/local/bin /usr/local/bin
COPY --from=node-src /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN rm -f /usr/local/bin/yarn /usr/local/bin/yarnpkg && npm install -g yarn

RUN pip install --no-cache-dir frappe-bench

RUN useradd -ms /bin/bash -u 1000 frappe
USER frappe
WORKDIR /home/frappe

COPY --chown=frappe:frappe scripts/entrypoint.sh /home/frappe/entrypoint.sh
ENTRYPOINT ["/home/frappe/entrypoint.sh"]
