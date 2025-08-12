# RHOAI MODEL TESTING

## workflow

1. create a new data science project
2. open the datascience project
3. click on the "connections" tab
   1. create a connection
   2. type: s3
   3. set the access key
   4. set the secret key
   5. use the fully qualified endpoint with the region like: `https://s3.us-east-2.amazonaws.com`
   6. set the region directly: `us-east-2`
   7. set the bucket name
4. create a pytorch workbench
   1. open the workbench and create a default notebook
   2. name the file "train.ipynb"
   3.

## train.ipynb

```
import os
import boto3
```

```
bucket_name = 'XXXXXX'
key_id = os.environ.get('AWS_ACCESS_KEY_ID')
secret_key = os.environ.get('AWS_SECRET_ACCESS_KEY')
```

```
# minimal MLP regressor that trains in seconds
import torch, torch.nn as nn, torch.optim as optim
import boto3, os, io

# ---- synthetic data ----
N, D = 2048, 10
X = torch.randn(N, D)
true_w = torch.randn(D, 1)
y = X @ true_w + 0.1*torch.randn(N,1)

# ---- tiny model ----
model = nn.Sequential(nn.Linear(D, 32), nn.ReLU(), nn.Linear(32, 1))
opt = optim.Adam(model.parameters(), lr=1e-2)
loss_fn = nn.MSELoss()

model.train()
for _ in range(200):  # ~<2s on CPU
    opt.zero_grad()
    pred = model(X)
    loss = loss_fn(pred, y)
    loss.backward()
    opt.step()

print("final MSE:", loss.item())

# ---- export to ONNX ----
model.eval()
dummy = torch.randn(1, D)
onnx_path = "/tmp/mlp_regressor.onnx"
torch.onnx.export(
    model, dummy, onnx_path,
    input_names=["input"], output_names=["output"],
    dynamic_axes={"input": {0: "batch"}, "output": {0: "batch"}},
    opset_version=12
)
```

```
# ---------- upload to S3 (uses your existing s3_client & bucket_name) ----------
import hashlib

# this folder+filename structure is crucial for openvino to work
# when we eventually host the model
object_key = "openvino/mlpregressor/1/model.onnx"

# compute sha256 for sanity
sha256 = hashlib.sha256()
with open(onnx_path, "rb") as f:
    data = f.read()
    sha256.update(data)

# upload
s3_client.upload_file(
    Filename=onnx_path,
    Bucket=bucket_name,
    Key=object_key,
    ExtraArgs={"ContentType": "application/octet-stream"},
)

# confirm
head = s3_client.head_object(Bucket=bucket_name, Key=object_key)
print(
    f"Uploaded: s3://{bucket_name}/{object_key}\n"
    f"Size: {head['ContentLength']} bytes | ETag: {head['ETag']} | sha256: {sha256.hexdigest()}"
)
```

## model prediction example

```
$ curl -sS -k -H "Authorization: Bearer ${TOKEN}"   -H 'Content-Type: application/json'   -d '{"instances":[[0.12,-0.5,0.3,1.0,0.0,-1.2,0.7,0.2,-0.9,0.05]]}'   $HOST/v1/models/mlpregressor:predict ; echo ""
{
    "predictions": [[-0.409755319]
    ]
}
```
