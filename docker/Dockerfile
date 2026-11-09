# SWG Source 64-bit server image.
# Based on tekaohswg/swg-docker (32-bit), built here as a 64-bit server.
# Ubuntu 18.04 provides GCC 7.5, the toolchain the 64-bit server was validated with.
FROM ubuntu:18.04

ARG DEBIAN_FRONTEND=noninteractive
ARG MAKE_JOBS=8

# What to build. Defaults to the current master of swg-main; its submodules
# (src, dsrc, configs, serverdata, stationapi) follow the *_branch settings
# in build.properties.
ARG SWG_MAIN_REPO=https://github.com/SWG-Source/swg-main.git
ARG SWG_MAIN_REF=master
ARG CMAKE_VERSION=3.17.5
ARG ORACLE_IC=21.18.0.0.0-1
ARG ORACLE_IC_DIR=2118000

RUN apt-get update && apt-get install -y --no-install-recommends \
        alien \
        ant \
        bison \
        build-essential \
        ca-certificates \
        flex \
        git \
        libaio1 \
        libboost-dev \
        libboost-program-options-dev \
        libcurl4-gnutls-dev \
        libncurses5-dev \
        libpcre3-dev \
        libsqlite3-dev \
        libxml2-dev \
        netbase \
        openjdk-11-jdk \
        perl \
        psmisc \
        python \
        sqlite3 \
        wget \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# The chat server needs CMake >= 3.14 (FindSQLite3); 18.04 ships 3.10.
RUN wget -q https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-Linux-x86_64.tar.gz \
    && tar -xzf cmake-${CMAKE_VERSION}-Linux-x86_64.tar.gz -C /opt \
    && ln -s /opt/cmake-${CMAKE_VERSION}-Linux-x86_64/bin/* /usr/local/bin/ \
    && rm cmake-${CMAKE_VERSION}-Linux-x86_64.tar.gz

# 64-bit Oracle Instant Client (basic includes ojdbc8.jar).
RUN for p in basic devel sqlplus; do \
        wget -q https://download.oracle.com/otn_software/linux/instantclient/${ORACLE_IC_DIR}/oracle-instantclient-${p}-${ORACLE_IC}.x86_64.rpm \
        && alien -i --scripts oracle-instantclient-${p}-${ORACLE_IC}.x86_64.rpm \
        && rm oracle-instantclient-${p}-${ORACLE_IC}.x86_64.rpm; \
    done

# The server loads Oracle and the 64-bit JVM from these at run time.
ENV ORACLE_HOME=/usr/lib/oracle/21/client64 \
    JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
ENV PATH=${ORACLE_HOME}/bin:${PATH} \
    LD_LIBRARY_PATH=${ORACLE_HOME}/lib:${JAVA_HOME}/lib/server

RUN git config --global user.name swg-docker && git config --global user.email swg-docker@localhost \
    && git clone ${SWG_MAIN_REPO} /swg-main \
    && cd /swg-main && git checkout ${SWG_MAIN_REF}
WORKDIR /swg-main

COPY swg.properties /swg-main/local.properties

RUN ant git_update_submods \
    && { git rev-parse HEAD; git submodule status; } > /swg-main/BUILD-REVISIONS.txt \
    && cat /swg-main/BUILD-REVISIONS.txt

# Compile everything that does not need a database.
RUN sed -i "s/<arg value=\"-j\${nproc}\"\/>/<arg value=\"-j${MAKE_JOBS}\"\/>/" build.xml \
    && ant compile_src
RUN ant compile_chat
RUN ant compile_java
RUN ant compile_miff compile_tab compile_tpf process_templates

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 44451-44453 44462-44464 44451-44453/udp 44462-44464/udp
CMD ["/entrypoint.sh"]
