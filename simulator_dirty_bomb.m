function [rad,KK,particle_vel]...
        =simulator_dirty_bomb(map_size,Num_steps,sources, ...
                                    source_strength,detonation, ...
                                    detonation_extent,wind_s,wind_l,wind_b,K,rho,draw)

rad=zeros([map_size Num_steps]);

max_rad=0;

nx=map_size(1);
ny=map_size(2);
nn=nx*ny;
xxinds=repmat(1:nx,1,ny);
yyinds=[];
for i=1:ny,
    yyinds=[yyinds i*ones(1,nx)];
end;

ddx=repmat(xxinds,nn,1)-repmat(xxinds,nn,1)';
ddy=repmat(yyinds,nn,1)-repmat(yyinds,nn,1)';
dd=sqrt(ddx.^2+ddy.^2);

KK=wind_s^2*exp(-dd.^2/wind_l^2);
KK=KK+1e-4*diag(diag(KK));

wind_dyns_x=mvnrnd(zeros(2*nn,1),[KK rho^Num_steps*KK; rho^Num_steps*KK KK])';
wind_dyns_y=mvnrnd(zeros(2*nn,1),[KK rho^Num_steps*KK; rho^Num_steps*KK KK])';

particle_vel1.x=wind_dyns_x(1:nn);
particle_vel1.y=wind_dyns_y(1:nn);

particle_vel2.x=wind_dyns_x(nn+1:end);
particle_vel2.y=wind_dyns_y(nn+1:end);

particle_vel.x(:,1)=particle_vel1.x;
particle_vel.y(:,1)=particle_vel1.y;

if draw
    % Plot wind vector field.
    figure(2)
    clf
    subplot(1,2,1)
    for i=1:nn,
        plot([yyinds(i) yyinds(i)+wind_b+particle_vel1.y(i)],[xxinds(i) ...
                            xxinds(i)-particle_vel1.x(i)-wind_b],'k-');
        hold on;
    end;
    axis tight
    axis off
    subplot(1,2,2)
    for i=1:nn,
        plot([yyinds(i) yyinds(i)+wind_b+particle_vel2.y(i)],[xxinds(i) ...
                            xxinds(i)-particle_vel2.x(i)-wind_b],'k-');
        hold on;
    end;
    drawnow
    axis tight
    axis off
end;

for tt=2:Num_steps,
    tt
    k=tt/Num_steps;
    particle_vel.x(:,tt)=(1-k)*particle_vel1.x+k*particle_vel2.x;
    particle_vel.y(:,tt)=(1-k)*particle_vel1.y+k*particle_vel2.y;

    if draw
        clf
        for i=1:nn,
            plot([yyinds(i) yyinds(i)+wind_b+particle_vel.y(i,tt)],[xxinds(i) xxinds(i)-particle_vel.x(i,tt)-wind_b],'k-');
            hold on;
        end;
        drawnow
        axis tight
        axis off
    end;
end;

for tt=2:Num_steps,
    old_rad=rad(:,:,tt-1);
    for i=1:size(sources,2),
        if tt>=detonation(i) & tt<detonation(i)+detonation_extent
            old_rad(sources(1,i),sources(2,i))=old_rad(sources(1,i), ...
                                                       sources(2,i))+source_strength(i);
        end;
    end;
    
    rad_new=zeros(map_size);

    out=zeros([map_size 8]);
    for i=1:map_size(1),
        for j=1:map_size(2),
            for th_ind=1:8,
                th=th_ind*pi/4;
    
                out(i,j,th_ind)=exp(cos(th)*(wind_b+particle_vel.x((i-1)*ny+j,tt))+sin(th)* ...
                                  (wind_b+particle_vel.y((i-1)*ny+j,tt)));
            end;
            out(i,j,:)=out(i,j,:)./repmat(sum(out(i,j,:),3),[1 1 8]);
        end;
    end;
    
    for th_ind=1:8;
        th=th_ind*pi/4;
        
        bx=(1:map_size(1))+sign(1e-6*round(cos(th)*1e6));
        by=(1:map_size(2))+sign(1e-6*round(sin(th)*1e6));
    
        iax=find(bx>0 & bx<=map_size(1));
        iay=find(by>0 & by<=map_size(2));
        ibx=bx(iax);
        iby=by(iay);

        rad_new(ibx,iby)=rad_new(ibx,iby)+K*old_rad(iax,iay).*squeeze(out(iax,iay,th_ind));
    end;
    rad_new(iax,iay)=rad_new(iax,iay)+(1-K)*old_rad(iax,iay);
    
    rad(:,:,tt)=rad_new;
    
    max_rad=max(max_rad,max(max(rad(:,:,tt))));
    
    if draw 
        % Plot radiation field.
        figure(1)
        clf
        map=min(1,rad(:,:,tt));
        imagesc(map);
        xlabel('Y','FontSize',20);
        ylabel('X','FontSize',20);
        axis square
    end;
end;
