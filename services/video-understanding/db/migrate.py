import os
import psycopg


def main():
    dsn = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/mychannel")
    sql_path = os.path.join(os.path.dirname(__file__), "models.sql")
    with open(sql_path, "r", encoding="utf-8") as f:
        ddl = f.read()
    with psycopg.connect(dsn, autocommit=True) as conn:
        with conn.cursor() as cur:
            cur.execute(ddl)
    print("Applied schema migrations.")


if __name__ == "__main__":
    main()



