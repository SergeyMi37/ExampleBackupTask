[![Gitter](https://img.shields.io/badge/Available%20on-Intersystems%20Open%20Exchange-00b2a9.svg)](https://openexchange.intersystems.com/package/apptools-task)
[![GitHub all releases](https://img.shields.io/badge/Available%20on-GitHub-black)](https://github.com/SergeyMi37/apptools-task)
[![Habr](https://img.shields.io/badge/Available%20article-on%20Intersystems%20Community-orange)](https://community.intersystems.com/post/recommendations-installing-intersystems-cach%C3%A9-dbms-production-environment)
[![Habr](https://img.shields.io/badge/Есть%20статья%20на-Хабре-blue)](https://habr.com/ru/company/intersystems/blog/342476/)
[![license](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

# Example-Usful-Utilites

## What's new
Ability to work in a portal with a large number of users. 
An example of a backup task and a password-checking program for the PCI-DSS standard

## Installation with ZPM

If ZPM the current instance is not installed, then in one line you can install the latest version of ZPM.
```
set $namespace="%SYS", name="DefaultSSL" do:'##class(Security.SSLConfigs).Exists(name) ##class(Security.SSLConfigs).Create(name) set url="https://pm.community.intersystems.com/packages/zpm/latest/installer" Do ##class(%Net.URLParser).Parse(url,.comp) set ht = ##class(%Net.HttpRequest).%New(), ht.Server = comp("host"), ht.Port = 443, ht.Https=1, ht.SSLConfiguration=name, st=ht.Get(comp("path")) quit:'st $System.Status.GetErrorText(st) set xml=##class(%File).TempFilename("xml"), tFile = ##class(%Stream.FileBinary).%New(), tFile.Filename = xml do tFile.CopyFromAndSave(ht.HttpResponse.Data) do ht.%Close(), $system.OBJ.Load(xml,"ck") do ##class(%File).Delete(xml)
```
If ZPM is installed, then ZAPM can be set with the command
```
zpm:%SYS>install example-useful-utils
```
## Installation with Docker

## Prerequisites
Make sure you have [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git) and [Docker desktop](https://www.docker.com/products/docker-desktop) installed.

## Installation 
Clone/git pull the repo into any local directory

```
$ git clone https://github.com/SergeyMi37/ExampleBackupTask.git
```

Open the terminal in this directory and run:

```
$ docker-compose build
```

3. Run the IRIS container with your project:

```
$ docker-compose up -d
```

## How to Test it
Open IRIS terminal:

```
$ docker-compose exec iris iris session iris
USER>
USER>zpm
zpm:USER>install example-useful-utils
```

