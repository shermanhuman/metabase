# Dockerfile for multi-architecture support (amd64 and arm64)

###################
# STAGE 1: builder
###################
FROM node:18-bullseye AS builder
ARG MB_EDITION=oss
ARG VERSION=unknown
WORKDIR /home/node

RUN apt-get update && apt-get upgrade -y && \
    apt-get install openjdk-11-jdk curl git -y

# Install Clojure
RUN curl -O https://download.clojure.org/install/linux-install-1.11.1.1262.sh && \
    chmod +x linux-install-1.11.1.1262.sh && \
    ./linux-install-1.11.1.1262.sh

COPY . .
# version is pulled from git, but git doesn't trust the directory due to different owners
RUN git config --global --add safe.directory /home/node

# install frontend dependencies
RUN yarn --frozen-lockfile
RUN INTERACTIVE=false CI=true MB_EDITION=$MB_EDITION bin/build.sh :version ${VERSION:-unknown}

###################
# STAGE 2: runner
###################
FROM eclipse-temurin:11-jre-jammy AS runner
ENV FC_LANG=en-US \
    LC_CTYPE=en_US.UTF-8

# Install dependencies
RUN apt-get update && \
    apt-get install -y curl fontconfig && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set up certificates
RUN mkdir -p /app/certs && \
    curl -o /app/certs/rds-combined-ca-bundle.pem https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem && \
    curl -o /app/certs/DigiCertGlobalRootG2.crt.pem https://cacerts.digicert.com/DigiCertGlobalRootG2.crt.pem && \
    for CACERTS in /etc/ssl/certs/java/cacerts "$JAVA_HOME/lib/security/cacerts"; do \
      if [ -f "$CACERTS" ]; then \
        keytool -noprompt -import -trustcacerts -alias aws-rds -file /app/certs/rds-combined-ca-bundle.pem -keystore "$CACERTS" -keypass changeit -storepass changeit; \
        keytool -noprompt -import -trustcacerts -alias azure-cert -file /app/certs/DigiCertGlobalRootG2.crt.pem -keystore "$CACERTS" -keypass changeit -storepass changeit; \
        echo "Updated cacerts at $CACERTS"; \
      fi; \
    done && \
    mkdir -p /plugins && chmod a+rwx /plugins

# add Metabase script and uberjar
COPY --from=builder /home/node/target/uberjar/metabase.jar /app/
COPY bin/docker/run_metabase.sh /app/

# expose our default runtime port
EXPOSE 3000

# run it
ENTRYPOINT ["/app/run_metabase.sh"]
