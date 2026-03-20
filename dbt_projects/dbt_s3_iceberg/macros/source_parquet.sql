{% macro source_parquet(source_name, table_name) %}

  {%- set sources = var('s3_parquet_sources', {}) -%}

  {%- if source_name in sources and table_name in sources[source_name] -%}

    {%- set path = sources[source_name][table_name] -%}
    read_parquet('{{ path }}')

  {%- else -%}

    {{ exceptions.raise_compiler_error(
        "source_parquet: não encontrei '" ~ source_name ~ "." ~ table_name ~
        "' em vars.s3_parquet_sources"
    ) }}

  {%- endif -%}

{% endmacro %}