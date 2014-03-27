function [xNew,PNew]=predict(x,P,map_size,K,wind_b,KK,rho)

nx=map_size(1);
ny=map_size(2);

nstate=nx*ny;

F=zeros(nstate);
Gx=zeros(nstate);
Gy=zeros(nstate);

particle_vel.x=x(nstate+1:2*nstate);
particle_vel.y=x(2*nstate+1:end);
    
out=zeros([map_size 8]);

for i=1:nx,
    for j=1:ny,
        for th_ind=1:8,
            th=th_ind*pi/4;
    
    out(i,j,th_ind)=exp(cos(th)*(wind_b+particle_vel.x((i-1)*ny+j))+sin(th)* ...
                              (wind_b+particle_vel.y((i-1)*ny+j)));
    der_out.x(i,j,th_ind)=cos(th)*exp(cos(th)*(wind_b+particle_vel.x((i-1)*ny+j))+sin(th)* ...
                              (wind_b+particle_vel.y((i-1)*ny+j)));
    der_out.y(i,j,th_ind)=sin(th)*exp(+cos(th)*(wind_b+particle_vel.x((i-1)*ny+j))+sin(th)* ...
                              (wind_b+particle_vel.y((i-1)*ny+j)));
        
        end;
    end;
end;
normalisation=repmat(sum(out,3),[1 1 8]);
out=out./normalisation;
der_out.x=der_out.x.*(1-out)./normalisation;
der_out.y=der_out.y.*(1-out)./normalisation;
    
for th_ind=1:8;
    th=th_ind*pi/4;
        
    bx=(1:map_size(1))+sign(1e-6*round(cos(th)*1e6));
    by=(1:map_size(2))+sign(1e-6*round(sin(th)*1e6));
        
    iax=find(bx>0 & bx<=map_size(1));
    iay=find(by>0 & by<=map_size(2));
    ibx=bx(iax);
    iby=by(iay);

    [xa,ya]=meshgrid(iax,iay); % Convert block to N points.
    xa=reshape(xa,1,prod(size(xa)));
    ya=reshape(ya,1,prod(size(ya)));
            
    [xb,yb]=meshgrid(ibx,iby); % Convert block to N points.
            
    xb=reshape(xb,1,prod(size(xb)));
    yb=reshape(yb,1,prod(size(yb)));

    inda=sub2ind(map_size,xa,ya); % state vector index.
    indb=sub2ind(map_size,xb,yb); % state vector index.
            
    indF=sub2ind([nstate nstate],indb,inda);
            
    addition=reshape(squeeze(out(iax,iay,th_ind))',1, ...
                     length(iax)*length(iay));

    F(indF)=F(indF)+K*addition;

    der_additionx=reshape(squeeze(der_out.x(iax,iay,th_ind))',1, ...
                          length(iax)*length(iay));
    der_additiony=reshape(squeeze(der_out.y(iax,iay,th_ind))',1, ...
                          length(iax)*length(iay));
    
    Gx(indF)=Gx(indF)+K*(exp(x(inda)')-1).*der_additionx;
    Gy(indF)=Gy(indF)+K*(exp(x(inda)')-1).*der_additiony;
end;

F=F+(1-K)*eye(nstate);

xNew=x;
xNew(1:nstate,1)=log(F*(exp(x(1:nstate))-1)+1);
xNew(nstate+1:end,1)=rho*x(nstate+1:end,1);

Fn=F.*repmat(exp(x(1:nstate))'-1,nstate,1);
Fn2=F.*repmat(exp(x(1:nstate))',nstate,1);
Norm=repmat(sum(Fn,2)+1,1,nstate);
Fn=Fn2./Norm;

Gxn=Gx./Norm;
Gyn=Gy./Norm;

FF=rho*eye(3*nstate);
FF(1:nstate,1:nstate)=Fn;
FF(1:nstate,nstate+1:2*nstate)=Gxn;
FF(1:nstate,2*nstate+1:end)=Gyn;

FFs=sparse(FF);

PNew=FFs*P*FFs';

Q=zeros(3*nstate);
Q(nstate+1:2*nstate,nstate+1:2*nstate)=(1-rho^2)*KK;
Q(2*nstate+1:3*nstate,2*nstate+1:3*nstate)=(1-rho^2)*KK;

PNew=PNew+Q;