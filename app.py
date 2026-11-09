import os
from pathlib import Path

import pymysql
from flask import Flask, Response

app = Flask(__name__)


def connect() -> pymysql.Connection:
    return pymysql.connect(
        host=os.environ["DB_HOST"],
        user=os.environ["DB_USER"],
        password=Path("/run/secrets/db_password").read_text(),
        database=os.environ["DB_NAME"],
        ssl_ca="/etc/mysql/yandex-ca.pem",
        ssl_verify_cert=True,
        ssl_verify_identity=True,
        connect_timeout=5,
        read_timeout=5,
        write_timeout=5,
    )


@app.get("/health")
def health() -> tuple[dict[str, str], int]:
    try:
        with connect() as connection, connection.cursor() as cursor:
            cursor.execute("SELECT 1")
        return {"status": "ok"}, 200
    except pymysql.MySQLError:
        app.logger.exception("MySQL health check failed")
        return {"status": "unavailable"}, 503


@app.get("/")
def home() -> Response:
    try:
        with connect() as connection, connection.cursor() as cursor:
            cursor.execute(
                "CREATE TABLE IF NOT EXISTS visits "
                "(id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY)"
            )
            cursor.execute("INSERT INTO visits () VALUES ()")
            cursor.execute("SELECT COUNT(*) FROM visits")
            count = cursor.fetchone()[0]
            connection.commit()
    except pymysql.MySQLError:
        app.logger.exception("MySQL request failed")
        return Response("База данных недоступна", status=503, mimetype="text/plain")
    return Response(
        f'<!doctype html><html lang="ru"><meta charset="utf-8">'
        f"<title>Yandex Cloud</title><h1>Приложение в Yandex Cloud</h1>"
        f"<p>Посещений: {count}</p></html>",
        mimetype="text/html",
    )
