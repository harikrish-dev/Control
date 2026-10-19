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
        status = c.getstatus(dev_id)
        print(json.dumps({"success": True, "status": status}))
    except Exception as e:
        print(json.dumps({"success": False, "error": str(e)}))

def get_status(region, api_key, api_secret, dev_id):
    try:
        c = get_cloud(region, api_key, api_secret, dev_id)
        res = c.getstatus(dev_id)
        print(json.dumps(res))
    except Exception as e:
        print(json.dumps({"success": False, "error": str(e)}))

def send_switch(region, api_key, api_secret, dev_id, socket_num, is_on):
    try:
        c = get_cloud(region, api_key, api_secret, dev_id)
        commands = {
            "commands": [
                {"code": f"switch_{socket_num}", "value": is_on}
            ]
        }
        res = c.sendcommand(dev_id, commands)
        print(json.dumps({"success": True, "result": res}))
    except Exception as e:
        print(json.dumps({"success": False, "error": str(e)}))

def send_switch_all(region, api_key, api_secret, dev_id, is_on):
    try:
        c = get_cloud(region, api_key, api_secret, dev_id)
        commands = {
            "commands": [
                {"code": f"switch_{i}", "value": is_on} for i in range(1, 5)
            ]
        }
        res = c.sendcommand(dev_id, commands)
        print(json.dumps({"success": True, "result": res}))
    except Exception as e:
        print(json.dumps({"success": False, "error": str(e)}))

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
