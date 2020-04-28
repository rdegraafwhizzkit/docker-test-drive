FROM php:7-apache
COPY src/ /var/www/html/
EXPOSE 80

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=2 \
CMD curl -f http://localhost/ || exit 1
