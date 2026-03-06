// Real-time chat application example
// Demonstrates WebSocket usage and event handling

type message = {
  id: string,
  username: string,
  content: string,
  timestamp: float,
}

type chatRoom = {
  name: string,
  messages: ref<array<message>>,
  users: ref<array<string>>,
}

let rooms: ref<Js.Dict.t<chatRoom>> = ref(Js.Dict.empty())

// Generate unique ID
let generateId = (): string => {
  let timestamp = Deno.now()->Float.toString
  let random = Js.Math.random()->Float.toString
  `${timestamp}-${random}`
}

// Get or create room
let getRoom = (roomName: string): chatRoom => {
  switch Js.Dict.get(rooms.contents, roomName) {
  | Some(room) => room
  | None => {
      let newRoom = {
        name: roomName,
        messages: ref([]),
        users: ref([]),
      }
      Js.Dict.set(rooms.contents, roomName, newRoom)
      newRoom
    }
  }
}

// Message to JSON
let messageToJson = (msg: message): Js.Json.t => {
  Js.Json.object_(Js.Dict.fromArray([
    ("id", Js.Json.string(msg.id)),
    ("username", Js.Json.string(msg.username)),
    ("content", Js.Json.string(msg.content)),
    ("timestamp", Js.Json.number(msg.timestamp))
  ]))
}

// HTTP handlers
let handleHome = async (_req: Deno.request): promise<Deno.response> => {
  let html = `
<!DOCTYPE html>
<html>
<head>
  <title>Chat Room</title>
  <style>
    body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
    #messages { border: 1px solid #ccc; height: 400px; overflow-y: auto; padding: 10px; margin-bottom: 20px; }
    .message { margin-bottom: 10px; padding: 8px; background: #f5f5f5; border-radius: 4px; }
    .username { font-weight: bold; color: #0066cc; }
    .timestamp { font-size: 0.8em; color: #666; }
    #input-area { display: flex; gap: 10px; }
    #message-input { flex: 1; padding: 10px; font-size: 14px; }
    #send-button { padding: 10px 20px; background: #0066cc; color: white; border: none; cursor: pointer; }
    #send-button:hover { background: #0052a3; }
  </style>
</head>
<body>
  <h1>💬 Chat Room</h1>
  <div id="messages"></div>
  <div id="input-area">
    <input type="text" id="message-input" placeholder="Type a message..." />
    <button id="send-button">Send</button>
  </div>
  <p><small>Connected users: <span id="user-count">0</span></small></p>

  <script>
    const ws = new WebSocket('ws://localhost:8000/ws');
    const messages = document.getElementById('messages');
    const input = document.getElementById('message-input');
    const sendBtn = document.getElementById('send-button');
    const username = 'User' + Math.floor(Math.random() * 1000);

    ws.onmessage = (event) => {
      const msg = JSON.parse(event.data);
      const div = document.createElement('div');
      div.className = 'message';
      div.innerHTML = \`
        <span class="username">\${msg.username}</span>
        <span class="timestamp">[\${new Date(msg.timestamp).toLocaleTimeString()}]</span>
        <div>\${msg.content}</div>
      \`;
      messages.appendChild(div);
      messages.scrollTop = messages.scrollHeight;
    };

    const sendMessage = () => {
      const content = input.value.trim();
      if (content) {
        ws.send(JSON.stringify({ username, content }));
        input.value = '';
      }
    };

    sendBtn.onclick = sendMessage;
    input.onkeypress = (e) => e.key === 'Enter' && sendMessage();
  </script>
</body>
</html>
  `
  Deno.Response.html(html, ())
}

let handleRoomList = async (_req: Deno.request): promise<Deno.response> => {
  let roomList = Js.Dict.entries(rooms.contents)->Array.map(((name, room)) => {
    Js.Json.object_(Js.Dict.fromArray([
      ("name", Js.Json.string(name)),
      ("userCount", Js.Json.number(Int.toFloat(Array.length(room.users.contents)))),
      ("messageCount", Js.Json.number(Int.toFloat(Array.length(room.messages.contents))))
    ]))
  })

  Deno.Response.json(Js.Json.array(roomList), ())
}

let handleRoomMessages = async (req: Deno.request): promise<Deno.response> => {
  let url = Deno.Request.url(req)
  let urlObj = Deno.Url.make(url)
  let path = Deno.Url.pathname(urlObj)
  let parts = path->Js.String2.split("/")->Array.keep(p => p !== "")

  if Array.length(parts) >= 3 {
    let roomName = Array.getUnsafe(parts, 2)
    let room = getRoom(roomName)
    let messagesJson = room.messages.contents->Array.map(messageToJson)->Js.Json.array

    Deno.Response.json(messagesJson, ())
  } else {
    Deno.Response.json(
      Js.Json.object_(Js.Dict.fromArray([
        ("error", Js.Json.string("Room name required"))
      ])),
      ~status=400,
      ()
    )
  }
}

let router = Router.make()
  ->Router.use(Middleware.logger())
  ->Router.get("/", handleHome)
  ->Router.get("/api/rooms", handleRoomList)
  ->Router.get("/api/rooms/:name/messages", handleRoomMessages)
  ->Router.get("/ws", async _req => {
    // WebSocket upgrade would happen here
    Deno.Response.text("WebSocket endpoint", ~status=426, ())
  })

Server.withRouter(~port=8000, router)
