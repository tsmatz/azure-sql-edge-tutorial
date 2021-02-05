FROM python:3.7-slim-buster

WORKDIR /app

COPY requirement.txt ./
RUN pip install -r requirement.txt

COPY . .

CMD [ "python3", "-u", "./data-generator.py" ]