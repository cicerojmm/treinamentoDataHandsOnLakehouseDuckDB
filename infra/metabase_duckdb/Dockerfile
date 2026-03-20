FROM eclipse-temurin:21-jre

ENV MB_PLUGINS_DIR=/plugins
ENV MB_DB_TYPE=postgres
ENV MB_DB_DBNAME=metabase
ENV MB_DB_PORT=5432
ENV MB_DB_USER=metabase
ENV MB_DB_PASS=metabase
ENV MB_DB_HOST=postgres

RUN mkdir -p ${MB_PLUGINS_DIR} /app /duckdb

# Metabase JAR
ADD https://downloads.metabase.com/latest/metabase.jar /app/metabase.jar

# Driver DuckDB (MotherDuck)
ADD https://github.com/MotherDuck-Open-Source/metabase_duckdb_driver/releases/latest/download/duckdb.metabase-driver.jar ${MB_PLUGINS_DIR}/

EXPOSE 3000
CMD ["java", "-jar", "/app/metabase.jar"]