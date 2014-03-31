function [id, payload] = get_message( channel )

idx = zmq('poll',10);

if(numel(idx) ~= 0)
    for c=1:numel(idx)
        if idx(c) == channel
            s_id = idx(c);
            data = zmq( 'receive', s_id );
            disp(char(data'))
            message = loadjson(char(data)');
        end
    end
    id = message.id;
    payload = message.payload;
else
    id = 'NONE';
    payload = '';
end

end