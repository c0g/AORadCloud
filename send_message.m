function send_message(channel, id, payload)
message.id = id;
message.payload = payload;
json = savejson('', message);
zmq( 'send', channel, json );
end