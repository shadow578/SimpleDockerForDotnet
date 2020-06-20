#Requires -RunAsAdministrator
param (
    [string] $imageName = $null,
    [bool] $exportImage = $true,
    [bool] $runContainer = $false,
    [bool] $writeLog = $false,
    [bool] $showVerbose = $true
)

function Get-WorkDir 
{
    $(Get-Location).Path
}

function Combine-Path([string] $a, [string] $b)
{
    [System.IO.Path]::Combine($a, $b)
}

function Write-Verbose([Parameter(ValueFromPipeline)][string] $msg) 
{
    if ($showVerbose)
    {
        Write-Host $msg -ForegroundColor Gray
    }
}

function Write-Information([Parameter(ValueFromPipeline)][string] $msg)
{
    Write-Host $msg -ForegroundColor White
}

function Write-Error([Parameter(ValueFromPipeline)][string] $msg)
{
    Write-Host $msg -ForegroundColor Red
}

function Test-DotnetInstalled 
{
    # check using Get-Command
    if (!(Get-Command "dotnet" -ErrorAction SilentlyContinue))
    {
        Write-Error "dotnet is not available! is dotnet core installed?"
        return $false
    }

    # check dotnet --version result
    try 
    {
        Write-Verbose "dotnet version: $(dotnet --version)"
    }
    catch 
    {
        # failed to run dotnet, probably not installed...
        Write-Error "dotnet is not availabel! is dotnet core installed?"
        return $false
    }

    # check exit code is 0
    return $LASTEXITCODE -eq 0        
}

function Test-DotnetProject 
{
    # check there is exactly one .csproj file in the workdir
    return (Get-ChildItem -Path $(Get-WorkDir) -Filter "*.csproj").Count -eq 1
}

function Test-DockerInstalled
{  
        # check using Get-Command
        if (!(Get-Command "docker" -ErrorAction SilentlyContinue))
        {
            Write-Error "docker is not availabel! is docker installed?"
            return $false
        }
    
        # check docker version result
        try 
        {
            Write-Verbose "docker version: $(docker version)"
        }
        catch 
        {
            # failed to run docker, probably not installed...
            Write-Error "docker is not availabel! is docker installed?"
            return $false
        }
    
        # check exit code is 0
        return $LASTEXITCODE -eq 0   
}

function Test-Dockerfile 
{
    # build path to dockerfile
    $df = Combine-Path -a $(Get-WorkDir) -b "dockerfile"

    # check there is a dockerfile in the work directory
    return (Test-Path -Path $df)
}

function Write-DefaultDockerFile 
{
    # build path to dockerfile
    $df = Combine-Path -a $(Get-WorkDir) -b "dockerfile"

   # write a default dockerfile 
@"
FROM mcr.microsoft.com/dotnet/core/runtime:3.1
COPY bin/Release/netcoreapp3.1/publish App/
WORKDIR /App
ENTRYPOINT [ "dotnet", "Foo.dll" ]
"@ | Out-File -FilePath $df
}

function Invoke-DotnetBuild 
{
    # check dotnet is installed
    if (!(Test-DotnetInstalled))
    {
        Write-Error "Could not find dotnet core installation! Aborting build."
        return $false
    }

    # check project file exists
    if (!(Test-DotnetProject))
    {
        Write-Error "Could not find dotnet project file (*.csproj)! Aborting build."
        return $false
    }

    # invoke build in release configuration
    dotnet publish -c Release | Write-Verbose

    # check if build was successfull
    return $LASTEXITCODE -eq 0
}

function Invoke-DockerBuild
{
   # check docker is installed
   if (!(Test-DockerInstalled))
   {
       Write-Error "Could not find docker installation! Aborting build."
       return $false
   }

   # check docker file exists
   if (!(Test-Dockerfile))
   {
       Write-DefaultDockerFile
       Write-Error "Could not find dockerfile!"
       Write-Error "A new dockerfile was created, you'll need to modify it first. Aborting build."
       return $false
   }

   # invoke docker build
   docker build -t $imageName -f Dockerfile $(Get-WorkDir) | Write-Verbose

   # check error code is 0
   return $LASTEXITCODE -eq 0
}

function Export-DockerImage
{   
   # build path to output file 
   $of = $(Combine-Path -a $(Get-WorkDir) -b "$($imageName).tar")

   # delete output file if it already exists
   if (Test-Path $of)
   {
       Write-Information "Removed previously exported container"
       Remove-Item $of
   }

   # invoke docker save
   docker save $imageName -o $of | Write-Verbose

   # check error code
   return $LASTEXITCODE -eq 0
}

function Invoke-DockerCreate 
{
   # invoke docker create, create a new container named the same as the image
   docker create --name $imageName $imageName | Write-Verbose

   # check exit code is 0
   return $LASTEXITCODE -eq 0
}

function Start-DockerContainer
{
   # start the container
   docker start $imageName | Write-Verbose

   # check exit code is 0
   return $LASTEXITCODE -eq 0
}

function Clean-DockerContainer 
{ 
    # to stop container
    docker stop $imageName | Write-Verbose
    
    # remove container
    docker rm $imageName | Write-Verbose
}

function Stop-Logging 
{
    if($writeLog)
    {
        Write-Information "stopping logging"
        Stop-Transcript
    }    
}


#start writing log file, if enabled
if ($writeLog)
{
    Start-Transcript -Path $(Combine-Path -a $(Get-WorkDir) -b "build-docker.log")
    Write-Information "started logging"
}

# check container name is ok
if ([string]::IsNullOrWhiteSpace($imageName))
{
    Write-Error "container name is not set. Set it using -imageName!"
    Stop-Logging
    exit 100
    return
}

# check dotnet and docker are installed, also print versions
Write-Information "dotnet version is: "
if (!(Test-DotnetInstalled))
{
    Write-Error "dotnet is not available!"
    Stop-Logging
    exit 1
    return
}

Write-Information "docker version is:"
if (!(Test-DockerInstalled))
{
    Write-Error "docker is not available!"
    Stop-Logging
    exit 1
    return
}


# build the dotnet app 
Write-Information "building dotnet app..."
if (!(Invoke-DotnetBuild))
{
    Write-Error "dotnet build failed!"
    Stop-Logging
    exit 2
    return 
}

# build docker container
Write-Information "building docker container..."
if (!(Invoke-DockerBuild))
{
    Write-Error "docker build failed!"
    Stop-Logging
    exit 3
    return
}

# export docker image (if enabled)
if($exportImage)
{
    Write-Information "exporting docker image..."
    if(!(Export-DockerImage))
    {
        Write-Error "failed to export image!"
        Stop-Logging
        exit 4
        return
    }
}

# run docker container (if enabled)
if($runContainer)
{
    Write-Information "cleaning up old container..."
    Clean-DockerContainer

    Write-Information "creating docker container..."
    if (Invoke-DockerCreate)
    {
        Write-Information "starting docker container..."
        if (!(Start-DockerContainer))
        {
            Write-Error "failed to start docker container"
            Stop-Logging
            exit 6
            return
        }
    }
    else 
    {
        Write-Error "failed to create docker container"
        Stop-Logging
        exit 5
        return
    }
}

# script finished without errors
Stop-Logging
exit 0