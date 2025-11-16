FROM authelia/authelia:latest

# Switch to root to copy files and set permissions
USER root

# Copy configuration files
COPY config/configuration.yml /config/configuration.yml
COPY config/users.yml /config/users.yml

# Create necessary directories and set permissions
RUN mkdir -p /config /secrets /var/log/authelia && \
    chmod -R 777 /config && \
    chmod -R 777 /secrets && \
    chmod -R 777 /var/log/authelia

# Copy entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/bin/sh", "/docker-entrypoint.sh"]
CMD ["authelia", "--config=/config/configuration.yml"]

