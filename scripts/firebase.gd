class_name AmbushFirebase
extends Node
## Public web configuration, shared with the user's other Ludoteca games.
## Tokens are device-local. This module never changes Firebase project rules.
var uid := ""
var id_token := ""
var refresh_token := ""
var token_at := 0.0
var last_error := ""
var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/firebase_public.json"))
var session_path := "user://ambush_auth.cfg"

func request(method: int, url: String, body: Variant = null, extra_headers:=PackedStringArray(), form:=false) -> Dictionary:
	var http:=HTTPRequest.new();http.timeout=15;http.accept_gzip=not OS.has_feature("web");add_child(http)
	var headers:=PackedStringArray(["Content-Type: application/x-www-form-urlencoded" if form else "Content-Type: application/json"])
	headers.append_array(extra_headers)
	var data: String="" if body==null else (str(body) if form else JSON.stringify(body))
	var error:=http.request(url,headers,method,data)
	if error!=OK:http.queue_free();last_error="Impossibile avviare la connessione.";return {"code":0,"data":null,"headers":[]}
	var result: Array=await http.request_completed;http.queue_free()
	if result[0]!=HTTPRequest.RESULT_SUCCESS:
		last_error="Connessione non disponibile. La partita locale è conservata.";return {"code":0,"data":null,"headers":[]}
	var code: int=result[1]
	var parsed=JSON.parse_string(result[3].get_string_from_utf8())
	if code>=300:last_error="Firebase: accesso non riuscito (%d)." % code
	return {"code":code,"data":parsed,"headers":result[2]}

func sign_in() -> bool:
	if id_token!="":return await fresh()
	var saved:=ConfigFile.new()
	if OS.has_feature("web"):
		var value=JavaScriptBridge.eval("sessionStorage.getItem('ambush_refresh') || ''")
		refresh_token=str(value) if value!=null else ""
	elif saved.load(session_path)==OK:refresh_token=saved.get_value("auth","refresh","")
	if refresh_token!="" and await refresh():return true
	var response:=await request(HTTPClient.METHOD_POST,"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key="+config.apiKey,{"returnSecureToken":true})
	if response.code!=200 or not response.data is Dictionary:return false
	uid=response.data.get("localId","");id_token=response.data.get("idToken","");refresh_token=response.data.get("refreshToken","");token_at=Time.get_unix_time_from_system();save_auth()
	return uid!="" and id_token!=""

func save_auth() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("sessionStorage.setItem('ambush_refresh', %s)" % JSON.stringify(refresh_token))
	else:
		var file:=ConfigFile.new();file.set_value("auth","refresh",refresh_token);file.save(session_path)

func refresh() -> bool:
	var response:=await request(HTTPClient.METHOD_POST,"https://securetoken.googleapis.com/v1/token?key="+config.apiKey,"grant_type=refresh_token&refresh_token="+refresh_token.uri_encode(),PackedStringArray(),true)
	if response.code!=200 or not response.data is Dictionary:return false
	id_token=response.data.get("id_token","");refresh_token=response.data.get("refresh_token",refresh_token);uid=response.data.get("user_id","");token_at=Time.get_unix_time_from_system();save_auth();return id_token!=""

func fresh() -> bool:
	return true if Time.get_unix_time_from_system()-token_at<3000 else await refresh()

func database(method: int, path: String, body: Variant=null, headers:=PackedStringArray()) -> Dictionary:
	if not await sign_in():return {"code":0,"data":null,"headers":[]}
	return await request(method,config.databaseURL+"/"+path+".json?auth="+id_token.uri_encode(),body,headers)

static func as_dict(value: Variant) -> Dictionary:
	if value is Dictionary:return value
	var result: Dictionary={}
	if value is Array:
		for i in value.size():
			if value[i]!=null:result[str(i)]=value[i]
	return result

static func etag(headers: Variant) -> String:
	for header in headers:
		if str(header).to_lower().begins_with("etag:"):return str(header).substr(5).strip_edges()
	return ""
