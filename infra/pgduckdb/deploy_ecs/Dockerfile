FROM pgduckdb/pgduckdb:17-main

# Set environment variables
ENV POSTGRES_USER=duckdb
ENV POSTGRES_DB=warehouse

# Copy initialization script
COPY ./init.sql /docker-entrypoint-initdb.d/

# Expose PostgreSQL port
EXPOSE 5432

# Health check
HEALTHCHECK --interval=15s --timeout=5s --retries=10 --start-period=30s \
  CMD pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}
