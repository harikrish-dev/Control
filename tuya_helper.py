import sys
import json
import warnings
warnings.filterwarnings("ignore")
import tinytuya

def get_cloud(region, api_key, api_secret, dev_id):
    c = tinytuya.Cloud(
        apiRegion=region,
        apiKey=api_key,
        apiSecret=api_secret,
        apiDeviceID=dev_id
    )
    return c

def test_connection(region, api_key, api_secret, dev_id):
    try:
        c = get_cloud(region, api_key, api_secret, dev_id)
        detail = c.cloudrequest(f"/v1.0/devices/{dev_id}")
        if detail and isinstance(detail, dict):
            res_data = detail.get("result", {})
            online = res_data.get("online", False)
            print(json.dumps({"success": True, "online": online, "status": res_data.get("status", [])}))
            return
        status = c.getstatus(dev_id)
        print(json.dumps({"success": True, "online": True, "status": status}))
    except Exception as e:
        print(json.dumps({"success": False, "online": False, "error": str(e)}))

def get_status(region, api_key, api_secret, dev_id):
    try:
        c = get_cloud(region, api_key, api_secret, dev_id)
        # Fetch device detail which contains the authoritative real-time "online" field
        detail = c.cloudrequest(f"/v1.0/devices/{dev_id}")
        if detail and isinstance(detail, dict) and "result" in detail:
            res_data = detail.get("result", {})
            is_online = res_data.get("online", False)
            status_items = res_data.get("status", [])
            print(json.dumps({
                "success": True,
                "online": is_online,
                "result": status_items if is_online else []
            }))
            return

        # Fallback to getstatus
        res = c.getstatus(dev_id)
        if isinstance(res, dict):
            print(json.dumps({
                "success": True,
                "online": True,
                "result": res.get("result", [])
            }))
        else:
            print(json.dumps({"success": False, "online": False, "result": []}))
    except Exception as e:
        print(json.dumps({"success": False, "online": False, "error": str(e)}))

def send_switch(region, api_key, api_secret, dev_id, socket_num, is_on):
    try:
        c = get_cloud(region, api_key, api_secret, dev_id)
        commands = {
            "commands": [
                {"code": f"switch_{socket_num}", "value": is_on}
            ]
        }
        res = c.sendcommand(dev_id, commands)
        # If Tuya reports result: False, the physical device is unpowered / offline
        if isinstance(res, dict) and res.get("result") is False:
            print(json.dumps({"success": False, "error": "Device is offline / unreachable", "result": res}))
            sys.exit(1)
        if isinstance(res, dict) and res.get("success") is True:
            print(json.dumps({"success": True, "result": res}))
        else:
            print(json.dumps({"success": False, "error": "Command failed", "result": res}))
            sys.exit(1)
    except Exception as e:
        print(json.dumps({"success": False, "error": str(e)}))
        sys.exit(1)

def send_switch_all(region, api_key, api_secret, dev_id, is_on):
    try:
        c = get_cloud(region, api_key, api_secret, dev_id)
        commands = {
            "commands": [
                {"code": f"switch_{i}", "value": is_on} for i in range(1, 5)
            ]
        }
        res = c.sendcommand(dev_id, commands)
        if isinstance(res, dict) and res.get("result") is False:
            print(json.dumps({"success": False, "error": "Device is offline / unreachable", "result": res}))
            sys.exit(1)
        if isinstance(res, dict) and res.get("success") is True:
            print(json.dumps({"success": True, "result": res}))
        else:
            print(json.dumps({"success": False, "error": "Command failed", "result": res}))
            sys.exit(1)
    except Exception as e:
        print(json.dumps({"success": False, "error": str(e)}))
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Missing action"}))
        sys.exit(1)

    action = sys.argv[1]
    if action == "test":
        test_connection(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])
    elif action == "status":
        get_status(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])
    elif action == "set":
        socket_num = int(sys.argv[6])
        is_on = sys.argv[7].lower() in ["true", "1", "on"]
        send_switch(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], socket_num, is_on)
    elif action == "set_all":
        is_on = sys.argv[6].lower() in ["true", "1", "on"]
        send_switch_all(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], is_on)
