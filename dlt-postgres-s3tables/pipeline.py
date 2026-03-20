"""
pipeline.py

Extrai dados do PostgreSQL e grava no S3 Tables (Iceberg) via dlt + PyIceberg.

Uso:
    python pipeline.py --tables orders customers  # tabelas específicas
    python pipeline.py --full-refresh             # recria todas as tabelas
    python pipeline.py                            # carga incremental (padrão)
"""

from __future__ import annotations

import argparse
import logging
import os

import dlt
import botocore.session
from dlt.sources.sql_database import sql_database, sql_table

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(__name__)

# ── Configurações ────────────────────────────────────────────
AWS_REGION       = os.environ.get("AWS_DEFAULT_REGION", "us-east-2")
NAMESPACE        = dlt.config.get("runtime.namespace") or os.environ.get("DLT_NAMESPACE", "main")


def _inject_env_vars_into_dlt_config() -> None:
    """dlt carrega automaticamente variáveis de ambiente com o padrão DESTINATION__FILESYSTEM__CREDENTIALS__*
    
    Não precisa de injeção manual — dlt já faz isso automaticamente!
    
    Variáveis esperadas no container:
        DESTINATION__FILESYSTEM__CREDENTIALS__AWS_ACCESS_KEY_ID
        DESTINATION__FILESYSTEM__CREDENTIALS__AWS_SECRET_ACCESS_KEY
        DESTINATION__FILESYSTEM__CREDENTIALS__REGION_NAME
        ICEBERG_CATALOG__ICEBERG_CATALOG_CONFIG__S3__ACCESS_KEY_ID
        ICEBERG_CATALOG__ICEBERG_CATALOG_CONFIG__S3__SECRET_ACCESS_KEY
    """
    # Apenas log informativo para debug
    aws_access_key_id = os.environ.get("DESTINATION__FILESYSTEM__CREDENTIALS__AWS_ACCESS_KEY_ID")
    aws_region = os.environ.get("DESTINATION__FILESYSTEM__CREDENTIALS__REGION_NAME", "us-east-2")
    
    if aws_access_key_id:
        log.info(f"✓ dlt carregará credenciais automaticamente do environment (region: {aws_region})")
    else:
        log.warning("⚠ Variáveis DESTINATION__FILESYSTEM__CREDENTIALS__* não encontradas")


def build_pipeline(full_refresh: bool = False) -> dlt.Pipeline:
    """Cria o pipeline dlt apontando para S3 Tables via filesystem + Iceberg."""
    # Injeta variáveis de ambiente no config dlt ANTES de criar o pipeline
    _inject_env_vars_into_dlt_config()
    
    pipeline = dlt.pipeline(
        pipeline_name="postgres_to_s3tables",
        destination="filesystem",
        dataset_name=NAMESPACE,
        dev_mode=False,
    )
    
    # Garante que o namespace existe no S3 Tables
    _ensure_namespace_exists()
    
    return pipeline

def _ensure_namespace_exists() -> None:
    """Cria o namespace no S3 Tables se não existir."""
    try:
        from pyiceberg.catalog import load_catalog
        import dlt
        
        # Carrega configurações do dlt
        config = dlt.config.get("iceberg_catalog.iceberg_catalog_config")
        
        catalog = load_catalog("s3tables", **config)
        
        # Tenta criar o namespace (ignora se já existe)
        try:
            catalog.create_namespace(NAMESPACE)
            log.info(f"Namespace '{NAMESPACE}' criado no S3 Tables")
        except Exception:
            log.info(f"Namespace '{NAMESPACE}' já existe")
            
    except Exception as e:
        log.warning(f"Não foi possível verificar/criar namespace: {e}")


def load_all_tables(
    schema: str | None = None,
    tables: list[str] | None = None,
    full_refresh: bool = False,
    incremental_column: str | None = None,
) -> None:
    pipeline = build_pipeline()
    write_disposition = "replace" if full_refresh else "append"

    log.info(
        "Iniciando carga: tabelas=%s schema=%s disposition=%s",
        tables or "TODAS", schema or "public", write_disposition,
    )

    if tables:
        # Roda uma tabela por vez — pipeline.run() não aceita lista de resources
        for table_name in tables:
            log.info("Carregando tabela: %s", table_name)

            if incremental_column:
                resource = sql_table(
                    table=table_name,
                    schema=schema or "public",
                    incremental=dlt.sources.incremental(incremental_column),
                )
            else:
                resource = sql_table(
                    table=table_name,
                    schema=schema or "public",
                )

            load_info = pipeline.run(
                resource,
                table_format="iceberg",
                write_disposition=write_disposition,
                loader_file_format="parquet",
            )
            _print_summary(load_info)

    else:
        # Todas as tabelas do schema
        source = sql_database(schema=schema or "public")

        load_info = pipeline.run(
            source,
            table_format="iceberg",
            write_disposition=write_disposition,
            loader_file_format="parquet",
        )
        _print_summary(load_info)


def load_with_merge(
    tables_config: list[dict],
    schema: str = "public",
) -> None:
    """
    Carga com estratégia merge (upsert) — ideal para tabelas com updates.

    tables_config exemplo:
        [
            {"table": "orders",    "primary_key": "id", "incremental": "updated_at"},
            {"table": "customers", "primary_key": "id", "incremental": "updated_at"},
        ]
    """
    pipeline = build_pipeline()
    resources = []

    for cfg in tables_config:
        resource = sql_table(
            table=cfg["table"],
            schema=schema,
            incremental=dlt.sources.incremental(cfg["incremental"])
            if cfg.get("incremental")
            else None,
        )
        resource.apply_hints(
            write_disposition={
                "disposition": "merge",
                "strategy"   : "upsert",
            },
            primary_key=cfg["primary_key"],
            table_format="iceberg",
        )
        resources.append(resource)

    load_info = pipeline.run(resources, loader_file_format="parquet")
    log.info("Merge concluído:\n%s", load_info)
    _print_summary(load_info)


def _print_summary(load_info) -> None:
    """Imprime resumo da carga."""
    print("\n" + "=" * 60)
    print("RESUMO DA CARGA")
    print("=" * 60)
    for package in load_info.load_packages:
        for job in package.jobs.get("completed_jobs", []):
            print(f"  ✅ {job.job_file_info.table_name}")
        for job in package.jobs.get("failed_jobs", []):
            print(f"  ❌ {job.job_file_info.table_name}: {job.failed_message}")
    print("=" * 60 + "\n")


if __name__ == "__main__":
    try:
        parser = argparse.ArgumentParser(description="Postgres → S3 Tables (Iceberg)")
        parser.add_argument("--tables",       nargs="+", help="Tabelas específicas")
        parser.add_argument("--schema",       default="public", help="Schema Postgres")
        parser.add_argument("--full-refresh", action="store_true")
        parser.add_argument("--incremental",  help="Coluna para carga incremental")
        parser.add_argument("--merge",        action="store_true", help="Usa upsert/merge")
        args = parser.parse_args()

        if args.merge and args.tables:
            tables_config = [
                {"table": t, "primary_key": "id", "incremental": args.incremental}
                for t in args.tables
            ]
            load_with_merge(tables_config, schema=args.schema)
        else:
            load_all_tables(
                schema=args.schema,
                tables=args.tables,
                full_refresh=args.full_refresh,
                incremental_column=args.incremental,
            )
        
        log.info("Pipeline executado com sucesso!")

    
    except Exception as e:
        log.error(f"Erro na execução do pipeline: {e}", exc_info=True)
        raise
    