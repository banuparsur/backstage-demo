
  
FROM bitnami/postgresql:latest AS build

USER root

ARG USE_POSTGIS=true
ENV PLUGIN_VERSION=v1.9.0.Alpha1
ENV PROTOC_VERSION=1.3

ENV WAL2JSON_COMMIT_ID=wal2json_2_3

# Install the packages which will be required to get everything to compile
RUN apt-get update \
    && apt-get install -f -y --no-install-recommends \
        software-properties-common \
        build-essential \
        pkg-config \
        git \
        postgresql-server-dev-$PG_MAJOR \
    && add-apt-repository "deb http://ftp.debian.org/debian testing main contrib" \
    && apt-get update && apt-get install -f -y --no-install-recommends \
        libprotobuf-c-dev=$PROTOC_VERSION.* \
    && rm -rf /var/lib/apt/lists/*

# Compile the plugin from sources and install it
RUN git clone https://github.com/debezium/postgres-decoderbufs -b $PLUGIN_VERSION --single-branch \
    && cd /postgres-decoderbufs \
    && make && make install \
    && cd / \
    && rm -rf postgres-decoderbufs

RUN git clone https://github.com/eulerto/wal2json -b master --single-branch \
    && cd /wal2json \
    && git checkout $WAL2JSON_COMMIT_ID \
    && make && make install \
    && cd / \
    && rm -rf wal2json


FROM bitnami/postgresql:latest

USER root

LABEL maintainer="Debezium Community"

ENV POSTGIS_VERSION=3

RUN apt-get update \
    && apt-get install -f -y --no-install-recommends \
        software-properties-common \
    && if [ "$USE_POSTGIS" != "false" ]; then apt-get install -f -y --no-install-recommends \
        postgresql-$PG_MAJOR-postgis-$POSTGIS_VERSION \
        postgresql-$PG_MAJOR-postgis-$POSTGIS_VERSION-scripts \
        postgis; \
       fi \
    && add-apt-repository "deb http://ftp.debian.org/debian testing main contrib" \
    && apt-get update && apt-get install -f -y --no-install-recommends \
        libprotobuf-c1 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /usr/lib/postgresql/$PG_MAJOR/lib/decoderbufs.so /usr/lib/postgresql/$PG_MAJOR/lib/wal2json.so /usr/lib/postgresql/$PG_MAJOR/lib/
COPY --from=build /usr/share/postgresql/$PG_MAJOR/extension/decoderbufs.control /usr/share/postgresql/$PG_MAJOR/extension/

USER 1001