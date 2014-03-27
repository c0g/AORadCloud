function save_rad(file,rad)

map_size(1)=size(rad,1);
map_size(2)=size(rad,2);
Num_steps=size(rad,3);

sim=fopen(file,'w');

fprintf(sim,'%d\n',map_size(1));
fprintf(sim,'%d\n',map_size(2));
fprintf(sim,'%d\n',Num_steps);

for tt=1:Num_steps,
    fprintf(sim,'%f\n',100*min(0.2,rad(:,:,tt))/0.2);
end;

fclose(sim);
