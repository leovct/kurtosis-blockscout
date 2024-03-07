POSTGRES_VERSION = "14"
POSTGRES_PORT = 5432
POSTGRES_DB = "blockscout"
POSTGRES_USER = "blockscout"
POSTGRES_PASSWORD = "ceWb1MeLBEeOIfk65gU8EjF8"


def start_postgres(plan):
    data = _init_postgres(plan)
    postgres = plan.add_service(
        name="postgres",
        config=ServiceConfig(
            image="postgres:{}-alpine".format(POSTGRES_VERSION),
            ports={
                "postgres": PortSpec(POSTGRES_PORT, application_protocol="postgresql"),
            },
            env_vars={
                "POSTGRES_DB": POSTGRES_DB,
                "POSTGRES_USER": POSTGRES_USER,
                "POSTGRES_PASSWORD": POSTGRES_PASSWORD,
            },
            files={
                "/var/lib/postgresql/data": data,
            },
            entrypoint=["/bin/sh", "-c"],
            cmd=[
                "postgres -c 'max_connections=200' -c 'client_connection_check_interval=60000'"
            ],
            user=User(uid=2000, gid=2000),
        ),
    )
    return "postgresql://{}:{}@{}:{}/blockscout".format(
        POSTGRES_USER, POSTGRES_PASSWORD, postgres.ip_address, POSTGRES_PORT
    )


def _init_postgres(plan):
    postgres = plan.add_service(
        name="postgres-init",
        config=ServiceConfig(
            image="postgres:{}-alpine".format(POSTGRES_VERSION),
            ports={
                "postgres": PortSpec(POSTGRES_PORT, application_protocol="postgresql"),
            },
            env_vars={
                "POSTGRES_DB": POSTGRES_DB,
                "POSTGRES_USER": POSTGRES_USER,
                "POSTGRES_PASSWORD": POSTGRES_PASSWORD,
            },
        ),
    )

    plan.exec(
        service_name="postgres-init",
        recipe=ExecRecipe(
            command=["/bin/sh", "-c", "chown -R 2000:2000 /var/lib/postgresql/data"],
        ),
    )

    data = plan.store_service_files(
        service_name="postgres-init",
        src="/var/lib/postgresql/data/*",
        name="postgres-data",
    )

    plan.remove_service(name="postgres-init")
    return data
