

Modify app.py:
To authenticate the connection between the flask app and mongo server inside kubernetes cluster, certain modifications are required.
The mongodb_url will change to 'mongodb://{USER_NAME}:{USER_PWD}@{DB_URL}' where USER_NAME, USER_PWD and DB_URL are environment variables. They will be defined in the Dockerfile we will create shortly. Virtual environment for Python is used to create an isolated environment for the project. It is used to provide consistence in dev/test/prod environments and makes it secure and managable.

Compose a Dockerfile:
This Dockerfile takes python:3.11.9-alpine3.19 as a base image. We create a directory 'flask-mongodb-app' where app.py and requirements.txt files are copied. Then pip installs the required packages. Flask runs in port 5000 so it is exposed for external access. The environment variables are also set here. Finally flask run command is executed.

Create a Docker Registry:
In this step create a personal public docker registry in DockerHub to push our docker image

Login to your DockerHub Account:
Before creating an image and pushing it to your registry, you must first login through cli. Type this command in command prompt
docker login -u="your_username" -p="your_password"

Create a docker image:
In command prompt go to the path where the Dockerfile is present.
docker build --no-cache -t app:v1.0 .
This command will create a docker image from your Dockerfile

Tag your docker image:
Tag the docker image to match your registry name before pushing it
docker tag app:v1.0 iswaryasv/demo-flask-app:v1.0

Push the image to DockerHub:
docker push iswaryasv/demo-flask-app:v1.0
Now we have successfully created a docker image and pushed it to our registry.

---------------------------------------------------------------------------------------------

Steps to  deploy the Flask application and MongoDB on a Minikube Kubernetes cluster

1. Install minikube on your machine:
run the following command for Windows:
winget install Kubernetes.minikube

2. Start the minikube cluster with docker driver:
minikube start --driver=docker

3. Compose the yaml files:

dev-space.yaml:
In this project, a namespace 'mongo' is created for our resources here.

mongo-secret.yaml:
This file contains the credentials required to access the mongo database. The username and password are base64 encoded.

mongo-config.yaml:
The database url is provided in this file.

app.yaml:
Contains deployment and service configurations. env values are referred from mongo-config and mongo-secret files. In the template section of Deployment, we have included the docker image we previously pushed to DockerHub. All the app pods will be created with this image. The app-service created is of type NodePort which is opened at port 30300.

mongo-volume.yaml:
A persisrent volume(PV) for the mongo database is configured

mongo-stateful.yaml:
Here, the mongodb service and a StatefulSet with persistent volume claim are configured. mongodb service is an internal service as only the flask app should be allowed to communicate with it.

4. Apply the yaml configurations:
kubectl apply -f dev-space.yaml
kubectl apply -f mongo-config.yaml
kubectl apply -f mongo-secret.yaml
kubectl apply -f mongo-volume.yaml
kubectl apply -f mongo-stateful.yaml
kubectl apply -f app.yaml

Note: As the flask app depends on the mongo database, it is created only after the database is created.

5. Check whether the resources are deployed:
To get a list of pods in namespace mongo:
kubectl get pods -n mongo
To get a list of every resource in namespace mongo:
kubectl get all -n mongo
Note the name of the app service running in the cluster. It is called 'app-service'

6. Start a tunnel for app-service
In order to access the app-service from our local machine, enter the command
minikube service app-service -n mongo

7. Copy the tunnel URL into a web browser:
Open a web browser, paste the url and press Enter. The date and time will be displayed.
The url looks like 'http://127.0.0.1//port'
Note: replace port with the port number displayed in your tunnel url.

8. Open Windows PowerShell:
We will be using the same ip used in step 7 to GET and POST data
POST command:
Invoke-RestMethod -Uri http://127.0.0.1:port/data -Method Post -Body '{"3": "three"}' -ContentType "application/json"
GET command:
Invoke-RestMethod -Uri http://127.0.0.1:port/data -Method Get
Note: replace port with the port number displayed in your tunnel url.

-----------------------------------------------------------------------------------------------------

DNS Resolution in Kubernetes:

In Kubernetes, DNS service is used for DNS resolution. This service is handled by coreDNS. Each service and pod gets a DNS record. A pod can be accessed using its DNS name instead of its IP.

To reach a service, a pod will lookup in the DNS records for that particular service. The DNS record is updated whenever a new service is created.
A normal service is assigned a A and/or AAAA record type which resolves to the clusterIP of that service.
A headless service is assigned a A and/or AAAA record type which resolves to the set of IPs of the pods selected by the service
A named port that is part of normal/headless service is assigned a SRV record. For a regular service, this resolves to a port number and a domain name. On the other hand, for a headless service, it resolves to the port number and domain name of the particular pod backing the service. This can have many answers.

Examples:

if a Pod in the mongo namespace has the IP address 172.15.1.42, and the domain name for that cluster is cluster.local, then the Pod has a DNS name:
172.15.1.42.mongo.pod.cluster.local.

Any Pods exposed by a Service have the following DNS resolution available:
pod-ip-address.service-name.my-namespace.svc.cluster-domain.example

----------------------------------------------------------------------------------------------------

Resource requests and limits:

CPU and memory are called resources here. 

When creating a pod, we can mention the resource limits which means that that pod cannot use more resources than we set. 

Resource request refers to the minimum amount of resource required to run the pod. Based on the resource request, Kubernetes will decide in which node to keep the pod.

Resource limits can be enforced to make sure that every pod gets the right amount of resources to run. If a pod attempts to use more CPU than assigned, the container will be throttled. It will be OOMkilled if it uses more memory than allocated and the container will be restarted.

----------------------------------------------------------------------------------------------------

Design Choices:

In this project, the app-service is of type NodePort. This allows external access. Initially I wanted to do this project in AWS with external load balancing(So the type of app-service would be LoadBalancer). But I decided to stick with minikube as I am a beginner.

I wanted the app-service and mongodb service to be in different namespaces. Anyway, I assigned them the same namespace for simplicity.

----------------------------------------------------------------------------------------------------

Testing auto-scaling:
I used HorizontalPodAutoScaler(HPA) for getting the desired minimum pods of 2 and maximum pods of 5. First I enabled the addon

minikube addons enable metrics-server

After applying the app.yaml file, I autoscaled the deployment app-deployment

kubectl autoscale deployment app-deployment --cpu-percent=70 --min=2 --max=5

for testing HPA, I ran a client pod that had a container which sent queries to my app-deployment

kubectl run -i --tty load-generator --rm --image=busybox:1.28 --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://app-deployment.mongo.svc.cluster.local:5000; done"

I saw the CPU utilization using the below command

kubectl get hpa php-apache --watch

One problem I encountered was that the CPU util did not go more than 26% in the pods. So I had to set cpu-percent to a lower value to test the auto-scaling feature. When I did that the pods scaled automatically based on the incoming traffic and cpu load.