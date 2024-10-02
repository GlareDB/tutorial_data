# Installation
Sys.setenv(NOT_CRAN = "true")
install.packages("glaredb", repos = "https://community.r-multiverse.org")


# Import and setup
library(glaredb)

con <- glaredb_connect()

glaredb_sql(
  "SELECT * FROM 'https://github.com/GlareDB/glaredb/raw/main/testdata/parquet/userdata1.parquet'",
  con
) |>
  as_glaredb_table()


# Output as R dataframe
r_dataframe <- glaredb_sql(
  "SELECT * FROM 'https://github.com/GlareDB/glaredb/raw/main/testdata/parquet/userdata1.parquet'",
  con
) |>
  as.data.frame()

head(r_dataframe)


# Output as Polars dataframe
library(polars)

polars_dataframe <- glaredb_sql(
  "SELECT * FROM 'https://github.com/GlareDB/glaredb/raw/main/testdata/parquet/userdata1.parquet'",
  con
) |>
  as_polars_df()

head(polars_dataframe)


# Local GlareDB persistence
con <- glaredb_connect("./my_db_path")
glaredb_execute("CREATE TABLE my_table AS SELECT 1", con)

## After closing your session, you can re-open a connection to the same directory
con <- glaredb_connect("./my_db_path")
glaredb_sql("SELECT * FROM my_table", con) |>
  as.data.frame()


# GlareDB Cloud
library(glue)
GLAREDB_CONNECTION_STRING <- Sys.getenv("GLAREDB_CONNECTION_STRING")
con <- glaredb_connect(GLAREDB_CONNECTION_STRING)
glaredb_sql("SELECT * FROM nyc_sales LIMIT 100", con) |>
  as.data.frame()


# Local .json
clickstream_data <- glaredb_sql("
  SELECT * FROM 'clickstream.json'
", con) |> as_polars_df()

head(clickstream_data)


# Select from a Polars dataframe
df <- glaredb_sql("
  SELECT * FROM clickstream_data where action = 'view'
", con) |> as.data.frame()

head(df)


# Join across Postgres and Snowflake
SNOWFLAKE_ACCOUNT <- Sys.getenv("SNOWFLAKE_ACCOUNT")
SNOWFLAKE_USERNAME <- Sys.getenv("SNOWFLAKE_USERNAME")
SNOWFLAKE_PASSWORD <- Sys.getenv("SNOWFLAKE_PASSWORD")
POSTGRES_USERNAME <- Sys.getenv("POSTGRES_USERNAME")
POSTGRES_PASSWORD <- Sys.getenv("POSTGRES_PASSWORD")

query <- glue::glue("
  SELECT postgres.borough_name, snowflake.* FROM 
    read_snowflake(
      '{SNOWFLAKE_ACCOUNT}', 
      '{SNOWFLAKE_USERNAME}',
      '{SNOWFLAKE_PASSWORD}',
      'sandbox',
      'compute_wh',
      'accountadmin',
      'public',
      'nyc_sales'
    ) snowflake 
  LEFT JOIN 
    read_postgres(
        'host=pg.demo.glaredb.com port=5432 user={POSTGRES_USERNAME} password={POSTGRES_PASSWORD} dbname=postgres',  
        'public',
        'borough_lookup'
    ) postgres ON
    snowflake.borough = postgres.borough_id
    limit 100  
")

df <- glaredb_sql(query, con) |> as.data.frame()

head(df)
