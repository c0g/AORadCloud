function [pub, sub] = open_channel(pub_port, sub_port)
%% Create ZMQ Stuff
pub = zmq( 'publish',   'tcp', '*', pub_port );
sub = zmq( 'subscribe', 'tcp', 'localhost', sub_port );
end