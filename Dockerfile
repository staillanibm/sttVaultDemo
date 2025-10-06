FROM iwhicr.azurecr.io/webmethods-edge-runtime:11.2.0 AS builder

ARG WPM_TOKEN
ARG GIT_TOKEN

RUN /opt/softwareag/wpm/bin/wpm.sh install -ws https://packages.webmethods.io -wr licensed -j $WPM_TOKEN -d /opt/softwareag/IntegrationServer WmJDBCAdapter:latest
RUN /opt/softwareag/wpm/bin/wpm.sh install -u staillanibm -p $GIT_TOKEN -r https://github.com/staillanibm -d /opt/softwareag/IntegrationServer sttVaultDemo

USER 0
RUN chgrp -R 0 /opt/softwareag && chmod -R g=u /opt/softwareag


FROM iwhicr.azurecr.io/webmethods-edge-runtime:11.2.0

USER 1724

COPY --from=builder /opt/softwareag /opt/softwareag
