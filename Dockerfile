FROM ruby:4.0.1-alpine3.23
LABEL maintainer="The Pew Project <contact@thepew.io>"

# Use --build-arg VERSION=... to override
# or `rake docker VERSION=...`
ARG VERSION=1.5.3

# sqlite3 aarch64 is broken on alpine, so use ruby:
# https://github.com/sparklemotion/sqlite3-ruby/issues/372
RUN apk add --no-cache build-base sqlite-libs sqlite-dev libstdc++ && \
    ( [ "$(uname -m)" != "aarch64" ] || gem install sqlite3 --version="~> 1.3" --platform=ruby ) && \
    gem install mailcatcher-ng -v "$VERSION" && \
    apk del --rdepends --purge build-base sqlite-dev

EXPOSE 1025 1080

ENTRYPOINT ["mailcatcher", "--foreground"]
CMD ["--ip", "0.0.0.0"]
