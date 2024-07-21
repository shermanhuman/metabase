# Dockerfile for multi-architecture support (amd64 and arm64)

   ###################
   # STAGE 1: builder
   ###################
   FROM node:18-bullseye AS builder
   ARG MB_EDITION=oss
   # set a default value for VERSION - this might not be a good change if Metabase folks want the
   # build to fail when it's not set.
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
   RUN INTERACTIVE=false CI=true MB_EDITION=$MB_EDITION bin/build.sh :version ${VERSION}

   ###################
   # STAGE 2: runner
   ###################
   FROM eclipse-temurin:11-jre-jammy AS runner
   ENV FC_LANG en-US LC_CTYPE en_US.UTF-8

   # Install dependencies
   RUN apt-get update && \
   apt-get upgrade -y && \
   apt-get install -y ca-certificates ca-certificates-java fonts-noto && \
   apt-get clean && \
   curl https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem -o /usr/local/share/ca-certificates/rds-combined-ca-bundle.pem && \
   curl https://cacerts.digicert.com/DigiCertGlobalRootG2.crt.pem -o /usr/local/share/ca-certificates/DigiCertGlobalRootG2.crt.pem && \
   update-ca-certificates && \
   mkdir -p /plugins && chmod a+rwx /plugins && \
   keytool -list -cacerts

   # add Metabase script and uberjar
   COPY --from=builder /home/node/target/uberjar/metabase.jar /app/
   COPY bin/docker/run_metabase.sh /app/

   # expose our default runtime port
   EXPOSE 3000

   # run it
ENTRYPOINT ["/app/run_metabase.sh"]
