# Use the pandoc/extra image as the base
FROM pandoc/extra:latest

# Install required packages
RUN apk add --no-cache openjdk11 graphviz ttf-dejavu && \
    wget https://github.com/plantuml/plantuml/releases/download/v1.2023.9/plantuml-1.2023.9.jar -O /usr/local/bin/plantuml.jar && \
    echo '#!/bin/sh' > /usr/local/bin/plantuml && \
    echo 'java -jar /usr/local/bin/plantuml.jar "$@"' >> /usr/local/bin/plantuml && \
    chmod +x /usr/local/bin/plantuml

# Install Python packages
RUN pip install pandoc-plantuml-filter --break-system-packages

# Setup work directory and environment variables
WORKDIR /data
RUN mkdir -p /data/.cache && \
    mkdir -p /data/.local
ENV XDG_CACHE_HOME=/data/.cache
ENV PATH=/data/.local/bin:/usr/local/bin:$PATH
ENV PYTHONUSERBASE=/data/.local

# Entry point
ENTRYPOINT ["pandoc"]

