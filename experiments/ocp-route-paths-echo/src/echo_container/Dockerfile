FROM python:3.11-slim

WORKDIR /app
COPY app.py .

RUN apt -y update && apt -y install curl jq
RUN pip install flask pyjwt requests

CMD ["python", "app.py"]
