Include %occKeyword

/// Класс задачи резервного копирования
Class %SYS.Task.CustomListBackup Extends %SYS.Task.Definition [ LegacyInstanceContext ]
{

/// Если ..AllDatabases=1, то в копию включать все базы данных ..PrefixIncludeDB и ..IncludeDatabases - игнорируются
Property AllDatabases As %Integer [ InitialExpression = 0 ];

/// Если ..AllDatabases=1, то в копию включать все базы данных , исключая из ..IgnoreForAllDatabases через запятую
Property IgnoreForAllDatabases As %String(MAXLEN = 32000) [ InitialExpression = "При AllDatabases=0 не применяется " ];

/// Если ..IgnoreTempDatabases=1, то исключать временные базы
Property IgnoreTempDatabases As %Integer [ InitialExpression = 1 ];

/// Если ..IgnorePreparedDatabases=1, то исключать предустановленные базы
Property IgnorePreparedDatabases As %Integer [ InitialExpression = 1 ];

/// Если ..AllDatabases=0 и если PrefixIncludeDB не пустое, то будем бэкапить все бд, имена которых начинаются на ..PrefixIncludeDB
Property PrefixIncludeDB As %String [ SqlComputeCode = {S {*}=..ListNS()}, SqlComputed ];

/// Если ..AllDatabases=0, то в копию включать все базы данных из ..IncludeDatabases , через запятую
Property IncludeDatabases As %String(MAXLEN = 32000) [ InitialExpression = {"При AllDatabases=1 не применяется "_..ListDB()} ];

/// Имя задачи в общем списке
Parameter TaskName = "CustomListBackup";

/// Путь, где хранить бэкапы
Property DirBackup As %String(MAXLEN = 1024) [ InitialExpression = {##class(%File).NormalizeDirectory("Backup")} ];

/// Путь, куда писать протокол
Property DirBackupLog As %String(MAXLEN = 1024) [ InitialExpression = {##class(%File).NormalizeDirectory("Backup")} ];

/// Тип копии (Full-Полный, Incremental-Инкрементальный, Cumulative-Комулятивный)
Property TypeBackup As %String(DISPLAYLIST = ",Full,Incremental,Cumulative", VALUELIST = ",Full,Inc,Cum") [ InitialExpression = "Full", SqlColumnNumber = 4 ];

/// Префикс имени файла бэкапа
Property PrefixBackUpFile As %String [ InitialExpression = "back" ];

/// Максимальное количество файлов бэкап, самые старые удалять
Property MaxBackUpFiles As %Integer [ InitialExpression = 3 ];

ClassMethod DeviceIsValid(Directory As %String) As %Status
{
 
	If '##class(%Library.File).DirectoryExists(Directory) quit $$$ERROR($$$GeneralError,"Directory does not exist")
	quit $$$OK
}

ClassMethod CheckBackup(Device, MaxBackUpFiles, del = 0) As %Status
{
 
	set path=##class(%File).NormalizeFilename(Device)
	quit:'##class(%File).DirectoryExists(path) $$$ERROR($$$GeneralError,"Директория "_path_" не существует") 
	set max=MaxBackUpFiles
	set result=##class(%ResultSet).%New("%File:FileSet")
	set st=result.Execute(path,"*.cbk",,1)
	while result.Next()
	{	If result.GetData(2)="F"	{
			continue:result.GetData(3)=0
			set ts=$tr(result.GetData(4),"-: ")
			set ts(ts)=$lb(result.GetData(1),result.GetData(3))			
		}
	}
	#; Обойдем все файлы начиная с самого нового
	set i="" for count=1:1 { set i=$order(ts(i),-1) quit:i=""
		#; Получаем прирост в байтах как разницу размера от предыдущего бэкап
		if $data(size),'$data(delta) set delta=size-$lg(ts(i),2)
		#; Получим размер в байтах самого свежего файла бэкап
		if '$data(size) set size=$lg(ts(i),2)
		#; Если количество файлов бэкап больше или равно максимального, то удаляем самые старые вместе с логами
		if count'<max {
			set cbk=$lg(ts(i),1)
			set log=$replace($lg(ts(i),1),".cbk",".log")
			if del { if ##CLASS(%File).Delete(cbk)
					if ##CLASS(%File).Delete(log)
			}
		}
	}
	do result.%Close()
	If $$$isUNIX quit $$$OK ##; Для линух не считаем	
	#; Высчитаем количество байт свободного места на диске
	set drive=$e(path,1)
	do ##CLASS(%File).GetDirectorySpace(drive_":/",.free,.total,0)
	#; Возращаем ошибку если прогнозируемый размер нового бэкап больше чем свободное место
	quit:($g(size)+$g(delta))>$g(free) $$$ERROR($$$GeneralError,"Прогнозируемый размер нового файла бэкап больше, чем свободное место на диске:("_$g(size)_"+"_$g(delta)_")>"_$g(free)) 
	quit $$$OK
}

Method OnTask() As %Status
{
 
	do $zu(5,"%SYS")
	set list=""
	merge oldDBList=^SYS("BACKUPDB")
	kill ^SYS("BACKUPDB")
	#; Добавление новых свойств для задание запуска бэкап
	set status=$$$OK
	try {
		##; Проврка на количество копий бд, если нужно то удалить самую старую
		##; Проверка на оставшийся объем на диске и прогнозируемый размер нового файла
		set status=..CheckBackup(..DirBackup,..MaxBackUpFiles,1)
		quit:$$$ISERR(status)
		#; Все базы данных
		if ..AllDatabases {
			set vals=""
			set disp=""
			set rss=##class(%ResultSet).%New("Config.Databases:List")
			do rss.Execute()
			while rss.Next(.sc) { 
				if ..IgnoreForAllDatabases'="",(","_..IgnoreForAllDatabases_",")[(","_$zconvert(rss.Data("Name"),"U")_",") continue
				if ..IgnoreTempDatabases continue:..IsTempDB(rss.Data("Name"))
				if ..IgnorePreparedDatabases continue:..IsPreparedDB(rss.Data("Name"))
				set ^SYS("BACKUPDB",rss.Data("Name"))=""
			}
		}
		else {
			#; если свойство PrefixIncludeDB не пустое, то будем бэкапить все бд имена которых начинаются на ..PrefixIncludeDB
			if ..PrefixIncludeDB'="" {
					set rss=##class(%ResultSet).%New("Config.Databases:List")
					do rss.Execute(..PrefixIncludeDB_"*")
					while rss.Next(.sc) { 
						if ..IgnoreTempDatabases continue:..IsTempDB(rss.Data("Name"))
						set ^SYS("BACKUPDB",rss.Data("Name"))=""
					}
			}
			#; Включим в список конкретные бд
			if ..IncludeDatabases'="" {
				set rss=##class(%ResultSet).%New("Config.Databases:List")
				do rss.Execute("*")
				while rss.Next(.sc) { 
					if ..IgnoreTempDatabases continue:..IsTempDB(rss.Data("Name"))
					if (","_..IncludeDatabases_",")'[(","_$zconvert(rss.Data("Name"),"U")_",") continue
					set ^SYS("BACKUPDB",rss.Data("Name"))=""
				}
			}
		}
		do ..GetFileName(.backFile,.logFile)
		set typeB=$zconvert($e(..TypeBackup,1),"U")
		set:"FIC"'[typeB typeB="F"
		set res=$$BACKUP^DBACK("",typeB,"",backFile,"Y",logFile,"NOINPUT","Y","Y","","","")
		if 'res set status=$$$ERROR($$$GeneralError,"Ошибка: "_res)
	} catch {	set status=$$$ERROR($$$GeneralError,"Ошибка: "_$ze) 
				set $ze=""
	  }
	kill ^SYS("BACKUPDB")
	merge ^SYS("BACKUPDB")=oldDBList
	quit status
}

/// Получить имена файлов
Method GetFileName(aBackupFile, ByRef aLogFile) As %Status
{
 
	set tmpName=..PrefixBackUpFile_"_"_..TypeBackup_"_"_$s(..AllDatabases:"All",1:"List")_"_"_$zd($h,8)_$tr($j($i(cnt),3)," ",0)
	do {
		s aBackupFile=##class(%File).NormalizeFilename(..DirBackup_"/"_tmpName_".cbk")
	} while ##class(%File).Exists(aBackupFile)
	set aLogFile=##class(%File).NormalizeFilename(..DirBackupLog_"/"_tmpName_".log")
	quit 1
}

/// Проверить предустановленная ли база данных
ClassMethod IsPreparedDB(name)
{
 
	if (",ENSDEMO,ENSEMBLE,ENSEMBLEENSTEMP,ENSEMBLESECONDARY,ENSLIB,CACHESYS,CACHELIB,CACHETEMP,CACHE,CACHEAUDIT,DOCBOOK,USER,SAMPLES,")[(","_$zconvert(name,"U")_",") quit 1
	quit 0
}

/// Проверить временная ли база данных
ClassMethod IsTempDB(name)
{
 
	quit:$zconvert(name,"U")["TEMP" 1
	quit:$zconvert(name,"U")["SECONDARY" 1
	quit 0
}

/// Получить список имен баз данных через запятую
ClassMethod ListDB()
{
 
	set list=""
	set rss=##class(%ResultSet).%New("Config.Databases:List")
	do rss.Execute()
	while rss.Next(.sc) { 
		set list=list_","_rss.Data("Name") 
	}
	quit list
}

ClassMethod ListNS() [ Private ]
{
 
	set disp=""
	set tRS = ##class(%ResultSet).%New("Config.Namespaces:List")
	set tSC = tRS.Execute()
	While tRS.Next() {	
				set disp=disp_","_tRS.GetData(1)
	}
	set %class=..%ClassName(1)
	$$$comSubMemberSet(%class,$$$cCLASSproperty,"PrefixIncludeDB",$$$cPROPparameter,"VALUELIST",disp)
	quit ""
}

ClassMethod oncompile() [ CodeMode = generator ]
{
 
	$$$defMemberKeySet(%class,$$$cCLASSproperty,"PrefixIncludeDB",$$$cPROPtype,"%String")
	set updateClass=##class("%Dictionary.ClassDefinition").%OpenId(%class)
	set updateClass.Modified=0
	do updateClass.%Save()
	do updateClass.%Close()
}

}

