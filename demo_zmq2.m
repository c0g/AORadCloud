clear all;
[pub, sub] = open_channel(5555, 5556);
num = 0;
while num < 10
    [id, payload] = get_message(sub);
    if ~strcmp(id, 'NONE')
        num = num + 1;
        disp(id)
        disp(payload)
    end
    
    send_message(pub, 'TEST_ID', [1, 2, 3]);
end
close_channel(pub, sub);