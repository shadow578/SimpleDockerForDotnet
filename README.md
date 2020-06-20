# Simple Docker for DotNet
This Script is a quick and easy way to get a dotnet application up and running inside a docker container.

### usage
Place script into the project root of your dotnet project (where the .csproj file is)

```
build a basic image:
build-docker.ps1 -imageName hello-docker

also export the image as tar:
build-docker.ps1 -imageName hello-docker -exportImage $true

and run the image in a new container for testing:
build-docker.ps1 -imageName hello-docker -exportImage $true -runContainer $true 

all that while logging script output:
build-docker.ps1 -imageName hello-docker -exportImage $true -runContainer $true -writeLog $true
```

### gitignore
i included a .gitignore with this script. 
you should include its entries in your gitignore if you use this script.
why, you ask? simple:
- the logs of the script contain info about your system, including your username. you might not want that
- the exported images of the script can be quite large (200+ MB)

### parameters
Name		| Description
------------|--------------------
imageName	| the image name to use
exportImage	| export the container image to tar
runContainer| run the container image
writeLog	| write a log of the script
showVerbose	| shows verbose output (mainly output of dotnet and docker commands)

### Disclaimer
This scripts are provided "as is" and are offered without any warranties, but with the hope that it will prove useful to someone.
The developer will not be held responsible for any damage caused by this script.

##### TL;DR
Use at your own risk. I didnt spend much time debugging it, so i wouldnt trust it too much ;)

