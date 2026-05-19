import json
import os

import boto3
from botocore.exceptions import ClientError


ec2 = boto3.client("ec2")


def _load_json_env(name):
    return json.loads(os.environ[name])


def _healthy_instance_ids(instance_ids):
    if not instance_ids:
        return set()

    response = ec2.describe_instance_status(
        InstanceIds=instance_ids,
        IncludeAllInstances=True,
    )

    healthy = set()
    for status in response.get("InstanceStatuses", []):
        state = status.get("InstanceState", {}).get("Name")
        instance_status = status.get("InstanceStatus", {}).get("Status")
        system_status = status.get("SystemStatus", {}).get("Status")

        if state == "running" and instance_status == "ok" and system_status == "ok":
            healthy.add(status["InstanceId"])

    return healthy


def _select_target(instances, healthy_ids):
    candidates = sorted(
        instances.items(),
        key=lambda item: (-int(item[1]["priority"]), item[0]),
    )

    for instance_key, config in candidates:
        if config["instance_id"] in healthy_ids:
            return instance_key, config

    return None, None


def _ensure_route(route_table_id, cidr, network_interface_id):
    try:
        ec2.replace_route(
            RouteTableId=route_table_id,
            DestinationCidrBlock=cidr,
            NetworkInterfaceId=network_interface_id,
        )
    except ClientError as exc:
        if exc.response["Error"]["Code"] != "InvalidRoute.NotFound":
            raise

        ec2.create_route(
            RouteTableId=route_table_id,
            DestinationCidrBlock=cidr,
            NetworkInterfaceId=network_interface_id,
        )


def handler(event, context):
    instances = _load_json_env("INSTANCE_CONFIG_JSON")
    route_table_ids = _load_json_env("ROUTE_TABLE_IDS_JSON")
    destination_cidrs = _load_json_env("DESTINATION_CIDRS_JSON")
    allocation_id = os.environ["EIP_ALLOCATION_ID"]

    healthy_ids = _healthy_instance_ids(
        [config["instance_id"] for config in instances.values()]
    )
    target_key, target = _select_target(instances, healthy_ids)

    if target is None:
        print("No healthy VPN instance found; leaving current routes unchanged")
        return {"active": None, "changed": False}

    network_interface_id = target["network_interface_id"]

    ec2.associate_address(
        AllocationId=allocation_id,
        NetworkInterfaceId=network_interface_id,
        AllowReassociation=True,
    )

    for route_table_id in route_table_ids:
        for cidr in destination_cidrs:
            _ensure_route(route_table_id, cidr, network_interface_id)

    print(f"VPN service is active on {target_key} ({target['instance_id']})")
    return {"active": target_key, "changed": True}
