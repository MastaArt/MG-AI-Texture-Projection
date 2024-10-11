/*  
[INFO] 
NAME=AI Texture Projection
VERSION=1.0.0
AUTHOR=MastaMan
DEV=https://3dground.net
HELP=
CLIENT=MaryGold Studio

[ABOUT]
A script that simplifies texture projeciton for the tyFlow plugin=

[FILES]
Install.mcr=
jpegoptim.exe=
convert.exe=

[1.0.0]
* Initial release =

[SCRIPT]
*/

struct '@' (
	currScript = getThisScriptFileName(),
	name = getFilenameFile currScript,
	pth = getFileNamePath currScript,
	ini = pth +  sysinfo.username + "@" + sysinfo.computername + ".ini",
	--ini = (getThisScriptFileName()) + ".ini",
	sec = name,
	
	fn trim s tag: "" = (
		s as string
		return (trimLeft (trimRight s tag) tag)
	),
	
	fn add k v sec: "" = (
		if (sec == "") do sec = this.sec
		if (v == undefined) do v = ""
		setIniSetting this.ini sec k (v as string)
	),
	
	fn get k sec: "" type: #string = (
		if (sec == "") do sec = this.sec
		
		if (k == "") do return getINISetting this.ini sec
		
		local v = getIniSetting this.ini sec k
		
		case type of (
			#bool_true: return if (v == "true") then true else false
			#bool_false: return if (v == "false") then false else true
			#int: return try (v as integer) catch(0)
		)
		
		return v
	),
	
	fn del k sec: "" = (
		if (sec == "") do sec = this.sec
		delIniSetting ini sec k
	),	
	
	fn delSec s = (
		delIniSetting ini s
	)
)

global '*' = '@'()

try(closeRolloutFloater floaterAITextureProjection) catch()
global floaterAITextureProjection = newRolloutFloater "Find Images In Archives" 300 200

rollout _rAITextureProjection "Find Images In Archives" category: 1 (
	group "Projection Image" (
		edittext edtProjecitonImage "" readonly: true across: 2 align: #left fieldwidth: 215 height: 22		
		button btnSelectProjecitonImage "..." width: 35 height: 24  align: #right offset: [0, -1]
		label lblGamma "Gamma: " across: 2 align: #left offset: [0, 3]
		dropdownList ddlGamma "" items: #("2.2", "1.0", "0.45") width: 70 offset: [-86, 0]
	)
	
	button btnProjectOnObject "Project On Object" height: 36 width: 260 offset: [0, 10]
	button btnSaveObject "Save Object" width: 260
	
	fn loadSettings = (
		local g = '*'.get "gamma" type: #int
		if (g != 0) do (ddlGamma.selection = g)
	)
	
	fn optimizeImages files: #() quality: 99 = (		
		local currentPath = getFilenamePath (getThisScriptFilename())		
		if (files.count == 0) do return false
		
		local jpgoptim = "\"" + currentPath + "jpegoptim.exe\""
		local p = getFilenamePath files[1]
		
		curDir = sysInfo.currentDir
		sysInfo.currentDir = p
		
		local imgs = ""
		
		for i in files do imgs += "\"" + (filenameFromPath i) + "\" "
		
		local cmd = jpgoptim + " --strip-all --all-progressive -f -o -q -m" + (quality as string) + "  " + imgs
		
		hiddenDosCommand cmd exitcode:&exitcode	
		
		sysInfo.currentDir = curDir 
	)
	
	fn convertImageToJPG f = (
		local currentPath = getFilenamePath (getThisScriptFilename())
		local converter = currentPath + "convert.exe"
		local temp = @"C:\temp\"
		local tmpConverter = temp + "convert.exe"			
		copyFile converter tmpConverter
		
		makeDir temp all: true
		
		local p = getFilenamePath f
		local n = getFilenameFile f
		local ext = getFilenameType f
		
		local ff = p + n + ".jpg"
		deleteFile ff
		
		local curDir = sysInfo.currentDir
		sysInfo.currentDir = temp
		
		local cmd = "convert.exe \"" + f + "\" \"" + ff + "\""
		
		hiddenDosCommand cmd exitcode:&exitcode			
		sysInfo.currentDir = curDir
		
		return ff
	)
	
	fn getRender = (
		local r = renderers.current as string
		
		if matchPattern r pattern:"*Corona*" do return #Corona
		if matchPattern r pattern:"*V_Ray*" do return #VRay
		if matchPattern r pattern:"*Default_Scanline*" do return #Scanline
		if matchPattern r pattern:"*mental_ray*" do return #Mentalray
		if matchPattern r pattern:"*iray_Renderer*" do return #IRay
		if matchPattern r pattern:"*maxwell*" do return #Maxwell
		if matchPattern r pattern:"*Arnold*" do return #Arnold
		if matchPattern r pattern:"*FStorm*" do return #FStorm
		
		return #UnsupportedRender
	)
	
	on btnSaveObject pressed do (
		if (selection.count == 0) do return messageBox "Please select object!" title: "Warning!"
		
		local f = getMAXSaveFileName()		
		if (f == undefined) do return false
		local p = getFilenamePath f
		
		saveNodes $ f quiet:true
		
		ShellLaunch p ""
	)
	
	on btnProjectOnObject pressed do (
		local f = edtProjecitonImage.text
		local r = getRender()
		local s = selection[1]
		local m = undefined 
		local g = ddlGamma.selected as float
		
		if (f == "" or not doesFileExist f) do return messageBox "Please select Projeciton Image!" title: "Warning!"
		if (selection.count != 1) do return messageBox "Please select one object!" title: "Warning!"
		if (s == undefined or superClassOf s != GeometryClass) do return messageBox "Please select object" title: "Warning!"
		
		local ff = convertImageToJPG f
		optimizeImages files: #(ff)
		
		if (isValidNode s and not isDeleted s and canConvertTo s Editable_Poly) do (
			try (s.modifiers[#tyUVWProjection].Coordinates = 1) catch (print "Can't set World param in tyUVWProjection modifier!")
			convertTo s Editable_Poly
		)
		
		
		local b = BitmapTexture bitmap: (openBitmap ff gamma: g)
		
		case r of (
			#Corona: (
				m = CoronaPhysicalMtl()
				m.baseTexmap = b
			)
			#VRay: (
				m = VRayMtl()
				m.texmap_diffuse = b
			)
			default: (
				m = PhysicalMaterial()
				m.base_color_map = b
			)
		)
		
		s.material = m
	)
	
	on btnSelectProjecitonImage pressed do (	
		local f = getOpenFileName caption: "Please select projection image" types:"PNG (*.png)|*.png"
		
		if (f == undefined) do return false
		
		edtProjecitonImage.text = f
		
		loadSettings()
	)
	
	on _rAITextureProjection open do (
		loadSettings()
	)
	
	on ddlGamma selected v do (
		'*'.add "gamma" v
	)
)

rollout _rAboutAITextureProjection "About" category: 999 (
	group "Description" (
		dotNetControl edtDescription "System.Windows.Forms.Textbox" align:#center height: 60
	)
	
	label lblDummy1 ""
	
	label lblName "" 
	label lblVer ""
	label lblClient ""
	
	label lblDummy2 ""
	
	label lblAuthor ""
	hyperlink lblCopy ""  align: #center color: orange
	
	label lblDummy3 ""
	
	timer tmrRestart "" active: false interval: 300
		
	fn downloadFile url dl = (
		deleteFile dl
		w = dotNetObject "System.Net.WebClient"			
		try(
			spm = dotNetClass "System.Net.ServicePointManager"
			spm.SecurityProtocol = spm.SecurityProtocol.TLS12				
			w.DownloadFile (url + "?time=" + timestamp() as string) dl				
		) catch(
			return false
		)
		
		return true
	)
	
	fn bgUpdate = (
		local url = "https://raw.githubusercontent.com/MastaArt/???????/main/"
		local main = url + "Batch GLB Converter.ms"
		
		local this = getThisScriptFileName()
		local p = getFileNamePath (getThisScriptFileName())
		local dl = this + ".tmp"
		local r = downloadFile main dl
		if(not r or not doesFileExist dl) do return print "Can't download updates!"
		local vn = getIniSetting dl "INFO" "VERSION"
		local vo = getIniSetting this "INFO" "VERSION"
		local additionalFiles = getIniSetting dl "FILES"
		
		if(vn > vo) do (
			deleteFile this
			renameFile dl this
			
			for n in additionalFiles do (
				local s = getIniSetting dl "FILES" n
				if (s == "") do downloadFile (url + n) (p + n)
				if (s == "deleted") do deleteFile (p + n)
			)
			
			tmrRestart.active = true
		)
		
		deleteFile dl
	)
	
	fn updateWorker = (
		m = dotnetobject "CSharpUtilities.SynchronizingBackgroundWorker"
		m.WorkerSupportsCancellation = true 
		m.CancelAsync() 
		dotNet.addEventHandler m "DoWork" bgUpdate
		m.RunWorkerAsync()	
	)
	
	fn getScriptInfo s releaseInfo: "" =  (
		if(releaseInfo != "") do (
			local r = getINISetting s releaseInfo
			return r
		)
		
		local v = getINISetting s "INFO" "VERSION"
		local a = getINISetting s "INFO" "AUTHOR"
		local n = getINISetting s "INFO" "NAME"
		local o = ""
		for i in (getINISetting s "ABOUT") do o += i + "\r\n"
		local d = getINISetting s "INFO" "DEV"
		local h = getINISetting s "INFO" "HELP"
		local c = getINISetting s "INFO" "CLIENT"
		
		struct data (version, author, name, description, developer, client, help, releases)
		
		local r = for i in (getINISetting s) where (i != "ABOUT" and i != "SCRIPT" and i != "COPY") collect i
		
		return (data version: v author: a name: n description: o developer: d client: c help: h releases: r)
	)
	
	on tmrRestart tick do (
		this = getThisScriptFileName()
		try(fileIn this) catch()
		vo = getIniSetting this "INFO" "VERSION"
		m = ("Script updated to version " + vo + "!\n\n\n")
		for c in (getIniSetting this vo) do (
			m += c + "\n"
		)
		
		--messageBox m title: "Success!" beep: false
		print "---UPDATED---"
		print m
		tmrRestart.active = false
	)

	on _rAboutAITextureProjection open do (
		edtDescription.MultiLine = true
		edtDescription.WordWrap = true
		edtDescription.ReadOnly = true
		edtDescription.BorderStyle = (dotNetClass "System.Windows.Forms.BorderStyle").FixedSingle
		
		
		local i = getScriptInfo (getThisScriptFilename())
		
		lblName.caption = i.name
		lblAuthor.caption = i.author
		lblVer.caption = i.version
		lblCopy.address = lblCopy.caption = i.developer
		lblClient.caption = i.client
		edtDescription.text = i.description
		
		try (floaterAITextureProjection.title = i.name + " " + i.version) catch()
		try (_rAITextureProjection.title = i.name + " v" +  i.version) catch()
		
		---!!!!!
		---updateWorker()
		
		local x = '*'.get "x"
		local y = '*'.get "y"
		
		if (x != "" and y != "") do (
			x = x as integer
			y = y as integer
			floaterAITextureProjection.pos = [x, y] 
		)		
	)
	
	on _rAboutAITextureProjection close do (
		local p = floaterAITextureProjection.pos
		
		'*'.add "x" p.x
		'*'.add "y" p.y
	)	
)

addRollout _rAITextureProjection floaterAITextureProjection rolledUp: false border: false
addRollout _rAboutAITextureProjection floaterAITextureProjection rolledUp: true