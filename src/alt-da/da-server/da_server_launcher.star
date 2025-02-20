shared_utils = import_module(
    "github.com/ethpandaops/ethereum-package/src/shared_utils/shared_utils.star"
)
constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)

# Port IDs
DA_SERVER_HTTP_PORT_ID = "http"

# Port nums
DA_SERVER_HTTP_PORT_NUM = 26658


def get_used_ports():
    used_ports = {
        DA_SERVER_HTTP_PORT_ID: shared_utils.new_port_spec(
            DA_SERVER_HTTP_PORT_NUM,
            shared_utils.TCP_PROTOCOL,
            shared_utils.HTTP_APPLICATION_PROTOCOL,
        ),
    }
    return used_ports


def launch_da_server(
    plan,
    service_name,
    image,
    cmd,
):
    config = get_da_server_config(
        plan,
        service_name,
        image,
        cmd,
    )
    da_server_service = plan.add_service(name=service_name, config=config)

    http_url = "http://{0}:{1}".format(
        da_server_service.ip_address, DA_SERVER_HTTP_PORT_NUM
    )

    # Wait for port 26658 to be available using the wait instruction with an HTTP request
    wait_recipe = GetHttpRequestRecipe(
        port=DA_SERVER_HTTP_PORT_ID,
        endpoint="/"
    )

    plan.wait(
        service_name=service_name,
        recipe=wait_recipe,
        field="code",
        assertion="==",
        target_value=200,
        interval="1s",
        timeout="30s",
        description="Waiting for DA server HTTP endpoint to be available"
    )

    # Fetch the auth token using run_sh
    auth_token_result = plan.run_sh(
        run="celestia bridge auth admin --node.store /home/celestia/bridge",
        image=image,  # Use the same image as the DA server
        description="Fetching DA server auth token"
    )

    # Strip whitespace from the auth token output
    auth_token = auth_token_result.output.strip()

    return new_da_server_context(
        http_url=http_url,
        auth_token=auth_token
    )

def get_da_server_config(
    plan,
    service_name,
    image,
    cmd,
):
    ports = get_used_ports()

    return ServiceConfig(
        image=image,
        ports=ports,
        cmd=cmd,
        private_ip_address_placeholder=constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
    )


def disabled_da_server_context():
    return new_da_server_context(
        http_url="",
        auth_token="",
    )


def new_da_server_context(http_url, auth_token=""):
    return struct(
        enabled=http_url != "",
        http_url=http_url,
        auth_token=auth_token,
    )
