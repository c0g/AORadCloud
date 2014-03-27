function [xNew,PNew]=fuse(x,P,map_size,xcoord,ycoord,obs,R,wind_b)

nstate=prod(map_size);
RR=diag(R);

H=zeros(3,3*nstate);
ind=sub2ind(map_size,xcoord,ycoord);
H(1,ind)=exp(x(ind));
H(2,nstate+ind)=1;
H(3,2*nstate+ind)=1;
K=P*H'*inv(H*P*H'+RR);

xNew=x+K*(obs-[exp(x(ind))-1; wind_b+x(nstate+ind); wind_b+x(2*nstate+ind)]);
PNew=P-K*(H*P);