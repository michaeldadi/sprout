#!/usr/bin/env python3
"""Terraform bridge for Appwrite settings missing from the official provider.

`read` follows hashicorp/external's string-map protocol. `apply` is called only
by terraform_data after a reviewed plan. Neither command prints API keys or
unfiltered project responses, and apply verifies the remote result.
"""

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"))


def config():
    if len(sys.argv) != 2 or sys.argv[1] not in ("read", "apply"):
        raise ValueError("Expected read or apply")
    if sys.argv[1] == "read":
        source = json.load(sys.stdin)
        endpoint = source["endpoint"]
        project_id = source["project_id"]
        kind = source["kind"]
        resource_id = source["id"]
        desired = None
    else:
        source = os.environ
        endpoint = source["SPROUT_APPWRITE_ENDPOINT"]
        project_id = source["SPROUT_APPWRITE_PROJECT_ID"]
        kind = source["SPROUT_APPWRITE_KIND"]
        resource_id = source["SPROUT_APPWRITE_ID"]
        desired = json.loads(source["SPROUT_APPWRITE_DESIRED"])
    parsed = urllib.parse.urlparse(endpoint)
    if parsed.scheme != "https" and not (parsed.scheme == "http" and parsed.hostname in ("127.0.0.1", "localhost")):
        raise ValueError("Appwrite endpoint must use HTTPS (or loopback HTTP for tests)")
    if not parsed.netloc or not parsed.path.rstrip("/").endswith("/v1"):
        raise ValueError("Expected an Appwrite /v1 endpoint")
    if kind not in ("bucket", "platform", "auth_method", "oauth_native", "service", "protocol", "policy"):
        raise ValueError("Unsupported Appwrite setting kind")
    if not resource_id or "/" in resource_id:
        raise ValueError("Invalid Appwrite resource ID")
    return endpoint.rstrip("/"), project_id, kind, resource_id, desired


def request(endpoint, project_id, method, path, body=None):
    key = os.environ.get("APPWRITE_API_KEY")
    if not key:
        raise ValueError("APPWRITE_API_KEY is required")
    data = None if body is None else canonical(body).encode("utf-8")
    req = urllib.request.Request(
        endpoint + path,
        data=data,
        method=method,
        headers={
            "Accept": "application/json",
            "Content-Type": "application/json",
            "X-Appwrite-Project": project_id,
            "X-Appwrite-Key": key,
            "X-Appwrite-Response-Format": "2.7.0",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        if exc.code == 404 and method == "GET":
            return None
        raise RuntimeError(f"Appwrite {method} {path} failed with HTTP {exc.code}") from None


def snapshot(endpoint, project_id, kind, resource_id):
    if kind == "bucket":
        row = request(endpoint, project_id, "GET", "/storage/buckets/" + resource_id)
        if row is None:
            return None
        return {
            "id": row["$id"],
            "name": row["name"],
            "permissions": row["$permissions"],
            "fileSecurity": row["fileSecurity"],
            "enabled": row["enabled"],
            "maximumFileSize": row["maximumFileSize"],
            "allowedFileExtensions": row["allowedFileExtensions"],
            "compression": row["compression"],
            "encryption": row["encryption"],
            "antivirus": row["antivirus"],
            "transformations": row["transformations"],
            "stripMetadata": row["stripMetadata"],
        }
    if kind == "platform":
        row = request(endpoint, project_id, "GET", "/project/platforms/" + resource_id)
        if row is None:
            return None
        result = {"id": row["$id"], "type": row["type"], "name": row["name"]}
        if row["type"] == "android":
            result["applicationId"] = row["applicationId"]
        elif row["type"] == "apple":
            result["bundleIdentifier"] = row["bundleIdentifier"]
        else:
            raise ValueError("Unexpected Appwrite platform type")
        return result
    if kind == "policy":
        result = request(endpoint, project_id, "GET", "/project/policies")
        if result is None:
            raise ValueError("Appwrite project policies were not found")
        row = next((item for item in result["policies"] if item["$id"] == resource_id), None)
        if row is None:
            raise ValueError("Appwrite project policy was not found")
        return {"id": resource_id, **{key: value for key, value in row.items() if not key.startswith("$")}}
    if kind == "oauth_native":
        if resource_id not in ("apple", "google"):
            raise ValueError("Only Apple and Google native OAuth are managed")
        row = request(endpoint, project_id, "GET", "/project/oauth2/" + resource_id)
        if row is None:
            raise ValueError("Appwrite OAuth provider was not found")
        return {
            "id": resource_id,
            "enabled": row["enabled"],
            "nativeEnabled": row["nativeEnabled"],
            "nativeClientIds": row["nativeClientIds"],
        }
    project = request(endpoint, project_id, "GET", "/project")
    if project is None:
        raise ValueError("Appwrite project was not found")
    collection = {"auth_method": "authMethods", "service": "services", "protocol": "protocols"}[kind]
    for row in project[collection]:
        if row["$id"] == resource_id:
            return {"id": resource_id, "enabled": row["enabled"]}
    raise ValueError(f"Appwrite {kind} was not found")


def apply(endpoint, project_id, kind, resource_id, desired):
    if desired["id"] != resource_id:
        raise ValueError("Terraform resource ID differs from desired ID")
    before = snapshot(endpoint, project_id, kind, resource_id)
    if before == desired:
        print(f"Appwrite {kind} {resource_id}: already matches Terraform")
        return
    if kind == "bucket":
        body = {key: value for key, value in desired.items() if key != "id"}
        if before is None:
            body["bucketId"] = resource_id
            request(endpoint, project_id, "POST", "/storage/buckets", body)
        else:
            request(endpoint, project_id, "PUT", "/storage/buckets/" + resource_id, body)
    elif kind == "platform":
        body = {key: value for key, value in desired.items() if key not in ("id", "type")}
        path = "/project/platforms/" + desired["type"]
        if before is None:
            body["platformId"] = resource_id
            request(endpoint, project_id, "POST", path, body)
        else:
            if before["type"] != desired["type"]:
                raise ValueError("Platform type cannot be changed in place")
            request(endpoint, project_id, "PUT", path + "/" + resource_id, body)
    elif kind in ("auth_method", "service", "protocol"):
        if before is None:
            raise ValueError(f"{kind} is missing from Appwrite project")
        path_segment = {"auth_method": "auth-methods", "service": "services", "protocol": "protocols"}[kind]
        request(endpoint, project_id, "PATCH", "/project/" + path_segment + "/" + resource_id, {"enabled": desired["enabled"]})
    elif kind == "oauth_native":
        if before is None:
            raise ValueError("OAuth provider is missing from Appwrite project")
        request(endpoint, project_id, "PATCH", "/project/oauth2/" + resource_id, {
            "enabled": desired["enabled"],
            "nativeEnabled": desired["nativeEnabled"],
            "nativeClientIds": desired["nativeClientIds"],
        })
    else:
        if resource_id == "account-devices":
            raise RuntimeError("Appwrite does not expose an update endpoint for account-devices policy")
        body = {key: value for key, value in desired.items() if key != "id"}
        if resource_id == "passkey":
            body = {"rpId": desired["rpId"]}
        request(endpoint, project_id, "PATCH", "/project/policies/" + resource_id, body)
    after = snapshot(endpoint, project_id, kind, resource_id)
    if after != desired:
        raise RuntimeError(f"Appwrite {kind} {resource_id} did not match Terraform after write")
    print(f"Appwrite {kind} {resource_id}: updated and verified")


def main():
    endpoint, project_id, kind, resource_id, desired = config()
    if sys.argv[1] == "read":
        print(canonical({"current": canonical(snapshot(endpoint, project_id, kind, resource_id))}))
    else:
        apply(endpoint, project_id, kind, resource_id, desired)


if __name__ == "__main__":
    try:
        main()
    except (KeyError, ValueError, RuntimeError, urllib.error.URLError) as exc:
        print(f"Appwrite Terraform bridge: {exc}", file=sys.stderr)
        sys.exit(1)
