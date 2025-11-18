from flask import Flask, jsonify
import pandas as pd
from azure.storage.blob import BlobServiceClient
import os
from io import BytesIO

app = Flask(__name__)

def read_csv_from_blob():
    account_name = os.getenv("AZURE_STORAGE_ACCOUNT")
    account_key = os.getenv("AZURE_STORAGE_KEY")
    container = os.getenv("CSV_CONTAINER")

    if not account_name or not account_key or not container:
        return {"erro": "Variáveis de ambiente ausentes."}

    conn_str = (
        f"DefaultEndpointsProtocol=https;"
        f"AccountName={account_name};"
        f"AccountKey={account_key};"
        f"EndpointSuffix=core.windows.net"
    )

    bsc = BlobServiceClient.from_connection_string(conn_str)
    blob = bsc.get_container_client(container).get_blob_client("sample_small.csv")

    data = blob.download_blob().readall()
    df = pd.read_csv(BytesIO(data))

    return df.to_dict(orient="records")

@app.route("/")
def index():
    try:
        data = read_csv_from_blob()
        return jsonify(data)
    except Exception as e:
        return jsonify({"erro": str(e)})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
