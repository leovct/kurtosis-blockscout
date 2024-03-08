postgres = import_module("github.com/kurtosis-tech/postgres-package/main.star")

POSTGRES_IMAGE = "postgres:14-alpine"
POSTGRES_USER = "blockscout"
POSTGRES_PASSWORD = "password"
POSTGRES_DB = "blockscout"


def run(plan, rpc_http_url, rpc_ws_url=""):
    postgres_url = postgres.start_postgres(plan)
    backend_host = start_blockscout_backend(
        plan, rpc_http_url, rpc_ws_url, postgres_url
    )

    # TODO: Start blockscout microservices
    # start_blockscout_sc_visualizer(plan)
    # start_blockscout_sig_provider(plan)
    # start_blockscout_sc_verifier(plan)

    start_blockscout_frontend(plan, backend_host, rpc_http_url)


def start_postgres(plan):
    postgres_output = postgres.run(
        plan,
        image=POSTGRES_IMAGE,
        service_name="blockscout-postgres",
        user=POSTGRES_USER,
        password=POSTGRES_PASSWORD,
        database=POSTGRES_DB,
        extra_configs=["max_connections=1000"],
        persistent=True,
    )
    return "postgresql://{user}:{password}@{hostname}:{port}/{database}".format(
        user=POSTGRES_USER,
        password=POSTGRES_PASSWORD,
        hostname=postgres_output.service.hostname,
        port=postgres_output.port.number,
        database=POSTGRES_DB,
    )


def start_blockscout_backend(plan, rpc_http_url, rpc_ws_url, postgres_url):
    backend = plan.add_service(
        name="blockscout-backend",
        config=ServiceConfig(
            image="blockscout/blockscout:latest",
            ports={
                "api": PortSpec(4000, application_protocol="http"),
            },
            env_vars={
                # https://docs.blockscout.com/for-developers/information-and-settings/env-variables
                "BLOCKSCOUT_HOST": "0.0.0.0",
                "BLOCKSCOUT_PROTOCOL": "http",
                "DATABASE_URL": postgres_url,
                "ETHEREUM_JSONRPC_VARIANT": "erigon",
                "ETHEREUM_JSONRPC_HTTP_URL": rpc_http_url,
                "ETHEREUM_JSONRPC_TRACE_URL": rpc_http_url,
                "ETHEREUM_JSONRPC_WS_URL": rpc_ws_url,
                "CHAIN_TYPE": "polygon_zkevm",
                "CHAIN_ID": "1",
                "ECTO_USE_SSL": "false",
            },
            entrypoint=["/bin/sh", "-c"],
            cmd=[
                'bin/blockscout eval "Elixir.Explorer.ReleaseTasks.create_and_migrate()" && bin/blockscout start',
            ],
        ),
    )
    return backend.ip_address


def start_blockscout_sc_visualizer(plan):
    plan.add_service(
        name="blockscout-sc-visualizer",
        config=ServiceConfig(
            image="ghcr.io/blockscout/visualizer:latest",
            # ports={
            #    "sc-visualizer": PortSpec(8081, application_protocol="http"),
            # },
        ),
    )


def start_blockscout_sig_provider(plan):
    plan.add_service(
        name="blockscout-sig-provider",
        config=ServiceConfig(
            image="ghcr.io/blockscout/sig-provider:latest",
            # ports={
            #    "sig-provider": PortSpec(8083, application_protocol="http"),
            # },
        ),
    )


def start_blockscout_sc_verifier(plan):
    plan.add_service(
        name="blockscout-sc-verifier",
        config=ServiceConfig(
            image="ghcr.io/blockscout/smart-contract-verifier:latest",
            # ports={
            #    "sc-verifier": PortSpec(8082, application_protocol="http"),
            # },
        ),
    )


def start_blockscout_frontend(plan, backend_host, rpc_http_url):
    plan.add_service(
        name="blockscout-frontend",
        config=ServiceConfig(
            image="ghcr.io/blockscout/frontend:latest",
            ports={
                "frontend": PortSpec(3000, application_protocol="http"),
            },
            env_vars={
                # https://docs.blockscout.com/for-developers/information-and-settings/env-variables/frontend-common-envs
                "NEXT_PUBLIC_API_HOST": backend_host,
                "NEXT_PUBLIC_API_PORT": "4000",
                "NEXT_PUBLIC_NETWORK_NAME": "(TEST) Polygon zkEVM",
                "NEXT_PUBLIC_NETWORK_ID": "1",
                "NEXT_PUBLIC_NETWORK_RPC_URL": rpc_http_url,
                "NEXT_PUBLIC_APP_HOST": "0.0.0.0",
            },
        ),
    )
