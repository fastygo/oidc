FROM authelia/authelia:latest

# Switch to root to copy files and set permissions
USER root

# Copy configuration files
COPY config/configuration.yml /config/configuration.yml
COPY config/users.yml /config/users.yml

# Create necessary directories and set permissions
RUN mkdir -p /config /secrets /var/log/authelia && \
    chmod -R 755 /config && \
    chmod -R 755 /secrets && \
    chmod -R 755 /var/log/authelia && \
    chown -R authelia:authelia /config /secrets /var/log/authelia

# Copy entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Switch back to authelia user
USER authelia

ENTRYPOINT ["/bin/sh", "/docker-entrypoint.sh"]
CMD ["authelia", "--config=/config/configuration.yml"]

