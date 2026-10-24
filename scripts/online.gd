class_name AmbushOnline
extends Node
signal updated
signal failed(message: String)
const Firebase = preload("res://scripts/firebase.gd")
var net: AmbushFirebase
var game: AmbushGame
var active := false
var host := false
var code := ""
var frame := 0
var busy := false
var polling := false
var timer := 0.0
var pending := false
var last_receipt: Dictionary = {}
var peer_uid := ""

func _ready() -> void:
	net=Firebase.new();add_child(net)

func packet() -> Dictionary:
	return {"kind":"ambush","version":1,"frame":frame,"state_json":JSON.stringify(game.snapshot()),"receipt":last_receipt}

func create(player: String) -> bool:
	if active:failed.emit("Sei già connesso a una stanza.");return false
	if not await net.sign_in():failed.emit(net.last_error);return false
	for attempt in 3:
		var candidate: String="A"+Crypto.new().generate_random_bytes(4).hex_encode().substr(0,7).to_upper()
		var read:=await net.database(HTTPClient.METHOD_GET,"rooms/"+candidate,null,PackedStringArray(["X-Firebase-ETag: true"]))
		if read.code!=200:failed.emit(net.last_error);return false
		if read.data!=null:continue
		var tag:=Firebase.etag(read.headers)
		if tag=="":failed.emit("Firebase non ha restituito il controllo di concorrenza necessario.");return false
		frame=0;last_receipt={}
		var room: Dictionary={"host":net.uid,"created":{".sv":"timestamp"},"status":"lobby","open":[0,1],"seats":{"0":{"uid":net.uid,"name":player}},"game":packet()}
		var result:=await net.database(HTTPClient.METHOD_PUT,"rooms/"+candidate,room,PackedStringArray(["if-match: "+tag]))
		if result.code==412:continue
		if result.code!=200:failed.emit(net.last_error);return false
		code=candidate;active=true;host=true;peer_uid="";updated.emit();return true
	failed.emit("Non è stato possibile creare una stanza. Riprova.");return false

func join(player: String, candidate: String) -> bool:
	if active:failed.emit("Sei già connesso a una stanza.");return false
	if candidate.length()!=8 or not candidate.begins_with("A") or not candidate.substr(1).is_valid_hex_number():failed.emit("Inserisci il codice Ambush di 8 caratteri.");return false
	var result:=await net.database(HTTPClient.METHOD_GET,"rooms/"+candidate)
	if result.code!=200 or not result.data is Dictionary:failed.emit("Stanza non disponibile. "+net.last_error);return false
	var room: Dictionary=result.data
	var game_packet: Dictionary=room.get("game",{})
	if game_packet.get("kind","")!="ambush" or game_packet.get("version",0)!=1:failed.emit("Stanza di un altro gioco o versione incompatibile.");return false
	if room.get("host")==net.uid:failed.emit("Questa è la tua stanza. Per il secondo giocatore usa un’altra scheda del browser o un altro dispositivo.");return false
	var saved=JSON.parse_string(game_packet.get("state_json",""))
	var validator:=AmbushGame.new()
	if not validator.restore(saved):failed.emit("Lo stato della stanza non è valido.");return false
	var seat_path: String="rooms/"+candidate+"/seats/1"
	var read:=await net.database(HTTPClient.METHOD_GET,seat_path,null,PackedStringArray(["X-Firebase-ETag: true"]))
	if read.code!=200:failed.emit(net.last_error);return false
	if read.data!=null and (not read.data is Dictionary or read.data.get("uid")!=net.uid):failed.emit("La stanza ha già due giocatori.");return false
	var tag:=Firebase.etag(read.headers)
	if tag=="":failed.emit("Impossibile verificare il posto libero.");return false
	var write:=await net.database(HTTPClient.METHOD_PUT,seat_path,{"uid":net.uid,"name":player},PackedStringArray(["if-match: "+tag]))
	if write.code!=200:failed.emit("Posto non disponibile. "+net.last_error);return false
	game.restore(saved);frame=int(game_packet.frame);code=candidate;host=false;active=true;pending=false;updated.emit();return true

func owns(command: Dictionary, is_host: bool) -> bool:
	return command.get("soldier","") in (["A","B","C","D"] if is_host else ["E","F","G","H"])

func submit(command: Dictionary) -> bool:
	if not active or busy or pending:return false
	if not owns(command,host):failed.emit("L’host controlla A–D; l’ospite controlla E–H.");return false
	var validation:=game.validate_command(command)
	if validation!="":failed.emit(validation);return false
	busy=true
	if host:
		var result:=await apply_as_host(command)
		busy=false;return result
	var result:=await net.database(HTTPClient.METHOD_PUT,"rooms/%s/turns/%d/1" % [code,frame],{"uid":net.uid,"frame":frame,"command":command})
	busy=false
	if result.code!=200:failed.emit(net.last_error);return false
	pending=true;return true

func apply_as_host(command: Dictionary) -> bool:
	var previous:=game.snapshot();var old_frame:=frame;var old_receipt:=last_receipt.duplicate(true)
	var result:=game.dispatch(command)
	frame+=1;last_receipt={"ok":result.ok,"message":result.get("error","")}
	var response:=await net.database(HTTPClient.METHOD_PUT,"rooms/%s/game"%code,packet())
	if response.code!=200:
		frame=old_frame;last_receipt=old_receipt;game.restore(previous);failed.emit("Azione non sincronizzata: ripristinato lo stato precedente. "+net.last_error);return false
	if not result.ok:failed.emit(result.error)
	updated.emit();return result.ok

func _process(delta: float) -> void:
	if not active:return
	timer+=delta
	if timer>=1.2 and not polling and not busy:
		timer=0;poll()

func poll() -> void:
	if not active or polling or busy:return
	polling=true
	var result:=await net.database(HTTPClient.METHOD_GET,"rooms/"+code)
	if not active:polling=false;return
	if result.code!=200 or not result.data is Dictionary:
		polling=false;failed.emit("Stanza non raggiungibile. Riprovo automaticamente; la partita è conservata.");return
	var room: Dictionary=result.data
	if not room.get("game") is Dictionary or room.game.get("kind")!="ambush":polling=false;failed.emit("Stanza non valida.");return
	if host:
		var seats:=Firebase.as_dict(room.get("seats"))
		peer_uid=str(seats.get("1",{}).get("uid",""))
		var turns:=Firebase.as_dict(room.get("turns"))
		var current:=Firebase.as_dict(turns.get(str(frame)))
		var proposal: Dictionary=current.get("1",{})
		if not proposal.is_empty() and proposal.get("uid")==peer_uid and peer_uid!="" and int(proposal.get("frame",-1))==frame and proposal.get("command") is Dictionary:
			if owns(proposal.command,false):
				busy=true;await apply_as_host(proposal.command);busy=false
	else:
		var remote: Dictionary=room.game
		if int(remote.get("frame",-1))>frame:
			var state=JSON.parse_string(remote.get("state_json",""))
			if game.restore(state):
				frame=int(remote.frame);pending=false
				if remote.get("receipt") is Dictionary and not remote.receipt.get("ok",true):failed.emit(remote.receipt.get("message","Comando rifiutato."))
				updated.emit()
	polling=false

func leave() -> void:
	active=false;pending=false;code="";host=false;updated.emit()
