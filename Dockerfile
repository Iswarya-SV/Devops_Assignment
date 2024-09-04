FROM python:3.11.9-alpine3.19
WORKDIR /flask-mongodb-app
COPY ./app.py /flask-mongodb-app/
COPY ./requirements.txt /flask-mongodb-app/

RUN pip3 install --upgrade pip && pip install --no-cache-dir -r /flask-mongodb-app/requirements.txt
EXPOSE 5000
ENV FLASK_APP /flask-mongodb-app/app.py
ENV FLASK-ENV development
ENV USER_NAME admin
ENV USER_PWD ad31nias68s
ENV DB_URL mongo-0:27017/
CMD [ "flask", "run", "--host", "0.0.0.0"]