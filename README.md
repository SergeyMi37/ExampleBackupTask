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

## Protection of event logs
You need to make sure that access to the %DB_CACHEAUDIT resource is restricted. That is, only the admin and those responsible for log monitoring have read and write rights to this resource.
Following the recommendations above, I have managed to install Caché in the maximum security mode. To demonstrate compliance with the requirements of PCI DSS section 8.2.5 “Forbid the use of old passwords”, I created a small application that will be launched by the system when the user attempts to change the password and will validate whether it has been used before.

To install this program, you need to import the source code using Caché Studio, Atelier or the class import page through the control panel
<pre><code>
ROUTINE PASSWORD
PASSWORD ; password verification program
#include %occInclude
CHECK(Username,Password) PUBLIC {
if '$match(Password,"(?=.*[0-9])(?=.*[a-zA-Z]).{7,}") quit $$$ERROR($$$GeneralError,"Password does not match the standard PCI_DSS_v3.2")
	set Remember=4 ; the number of most recent passwords that cannot be used according to PCI-DSS
	set GlobRef="^PASSWORDLIST" ; The name of the global link
	set PasswordHash=$System.Encryption.SHA1Hash(Password)
	if $d(@GlobRef@(Username,"hash",PasswordHash)){
	 	quit $$$ERROR($$$GeneralError,"This password has already been used ")
	}
	set hor=""
	for i=1:1 {
	 	; Traverse the nods chronologically from new to old ones
	 	set hor=$order(@GlobRef@(Username,"datetime",hor),-1)
	 	quit:hor=""
	 	; Delete the old one that’s over the limit
	 	if i>(Remember-1) {
		 	set hash=$g(@GlobRef@(Username,"datetime",hor))
		 	kill @GlobRef@(Username,"datetime",hor)
		 	kill:hash'="" @GlobRef@(Username,"hash",hash)
	 	}
	}
	; Save the current one
	set @GlobRef@(Username,"hash",PasswordHash)=$h
	set @GlobRef@(Username,"datetime",$h)=PasswordHash
	quit $$$OK
}
</code></pre>

Let’s save the name of the program in the management portal.
![Form_Password](https://habrastorage.org/webt/fh/27/s_/fh27s_lr75atpdmgg1enviw9klg.jpeg)

It happened so that my product configuration was different from the test one not only in terms of security but also in terms of users. In my case, there were thousands of them, which made it impossible to create a new user by copying settings from an existing one.
![Form_EditUser](https://habrastorage.org/webt/fz/bu/jx/fzbujxdud_5fi40qlbxixtf20_i.jpeg)

DBMS developers limited list output to 1000 elements. After talking to [the InterSystems WRC technical support service](https://login.intersystems.com/login/SSO.UI.Login.cls?referrer=https%253A//wrc.intersystems.com/wrc/login.csp), I learned that the problem could be solved by creating a special global node in the system area using the following command:

<pre><code>
%SYS>set ^CacheTemp.MgtPortalSettings($Username,"MaxUsers")=5000
</code></pre>
This is how you can increase the number of users shown in the dropdown list. I explored this global a bit and found a number of other useful settings of the current user. However, there is a certain inconvenience here: this global is mapped to the temporary CacheTemp database and will be removed after the system is restarted. This problem can be solved by saving this global before shutting down the system and restoring it after the system is restarted.
To this end, I wrote [two programs](http://docs.intersystems.com/ens20172/csp/docbook/DocBook.UI.Page.cls?KEY=GSTU_customize#GSTU_customize_startstop),^%ZSART and ^%ZSTOP, with the required functionality.

The source code of the %ZSTOP program
<pre><code>
%ZSTOP() {
	Quit	
}
/// save users’ preferences in a non-killable global
SYSTEM() Public {
	merge ^tmpMgtPortalSettings=^CacheTemp.MgtPortalSettings
	quit
}
</code></pre>

The source code of the %ZSTART program

<pre><code>
%ZSTART() {
	Quit	
}
///	restore users’ preferences from a non-killable global
SYSTEM() Public {
	if $data(^tmpMgtPortalSettings) merge ^CacheTemp.MgtPortalSettings=^tmpMgtPortalSettings
	quit
}
</code></pre>
Going back to security and the requirements of the standard, we can’t ignore the backup procedure. The PCI DSS standard imposes certain requirements for backing up both data and event logs. In Caché, all logged events are saved to the CACHEAUDIT database that can be included in the list of backed up databases along with other ones.
The Caché DBMS comes with several pre-configured backup jobs, but they didn’t always work for me. Every time I needed something particular for a project, it wasn’t there in “out-of-the-box” jobs. In one project, I had to automate the control over the number of backup copies with an option of automatic purging of the oldest ones. In another project, I had to estimate the size of the future backup file. In the end, I had to write my own backup task.
CustomListBackup.cls
