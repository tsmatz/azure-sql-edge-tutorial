from azure.iot.device import IoTHubModuleClient
import time
import datetime
import numpy as np
import json

module_client = IoTHubModuleClient.create_from_edge_environment()
# module_client.connect()

while True:
    timedat = datetime.datetime.utcnow().isoformat()
    msg = {
        "timestamp": timedat,
        "weight": np.random.normal(10.0, 3.0),
        "concentration": np.random.normal(20.0, 3.5)
    }
    msgstr = json.dumps(msg)
    module_client.send_message_to_output(msgstr, "output1")
    print("{} sent message: {}".format(timedat, msgstr))
    time.sleep(1)
