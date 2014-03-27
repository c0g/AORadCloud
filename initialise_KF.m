function [xNew,PNew]=initialise_KF(map_size,KK)

KK=KK+1e-3*diag(diag(KK));

nstate=prod(map_size);
xNew=[log(1+1e-10*ones(nstate,1)); zeros(2*nstate,1)];
PNew=zeros(3*nstate);
PNew(1:nstate,1:nstate)=1e-3*eye(nstate);
PNew(nstate+1:2*nstate,nstate+1:2*nstate)=KK;
PNew(2*nstate+1:end,2*nstate+1:end)=KK;