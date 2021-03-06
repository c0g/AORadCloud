clear all
close all
addpath(genpath(pwd))
generate_new_sim=0;    % 1 for new scenario.
draw=0;                % 1 to show ground truth for new scenario.
nagents=4;             % Number of cloud monitors.

nx=50;     
ny=55;
map_size=[nx ny];

nstate=prod(map_size); % Size of radiation cloud part of KF state vector.
nsteps=120;            % Time extent of simulation.
wd_sigma=0.01;         % Geiger counter measurement noise std.
gc_sigma=0.01;         % Wind speed measurement noise std.
wind_b=0.4;            % Bias in wind direction.
wind_s=0.8;            % Variance of wind speed.
rho=0.9;               % Correlation between x and y components of
                       % wind speed.

K=0.9;                 % Radiation diffusion rate.

sources=[[5; 10], [25; 25]];  % Locations of dirty bombs.
source_strength=[5; 10];      % Radioactivity of each source.
detonation=[1, 50];           % Time step when detonates.
detonation_extent=50;         % Time each bomb radiates.

try
    load('ground_truth');
catch e
    [rad,KK,particle_vel]=simulator_dirty_bomb(map_size,nsteps,sources,source_strength, ...
                         detonation,detonation_extent,wind_s,10,wind_b,K,rho,draw);
    fprintf(1,'Ground truth generated.\n\n');

    scale=100/(10+max(max(max(rad))));

    save_rad(['ground_truth.txt'],rad);
    save('ground_truth','rad','KK','particle_vel','rho','scale');
end

% ------- Main loop -------------------------

% REQUEST_GROUND_TRUTH=1 : Return GROUND_TRUTH radiation matrix.
% INITIALISE_ESTIMATOR=1 : Set time to first step and initialise
%     KF.  No output.
% REQUEST_CURRENT_STATE=1 : Return radiation matrix estimate mean
%     (EST_MEAN) and variance (EST_VAR) for current time step.  The
%     row and columns of each matrix are the X and Y-coordinates, respectively.
% FUSE_MEASUREMENTS=M : M is a list of responder ids and geo-locations
%     {(ID,X,Y)}.  Generate and fold in to estimate gieger-counter 
%     measurements from these responders.  Output list of geiger-counter
%     readings for each responder GEIGER={(ID,G)}.
% NEXT_STEP=1 : Move current state on one step.  No output.
% REQUEST_PREDICTION=N : Predict ahead N time steps from current
%     state and return corresponding radiation matrix estimate mean
%     (PRED_MEAN) and variance (PRED_VAR). The row and columns of
%     each matrix are the X and Y-coordinates, respectively.

INITIALISE_ESTIMATOR=1;
NEW_GROUND_TRUTH=0;
GET_GROUND_TRUTH=0;
SET_GROUND_TRUTH=0;
REQUEST_CURRENT_STATE=0;
REQUEST_PREDICTION=0;
NEXT_STEP=0;
TEST = 0;
BYPASS=1;
FUSE_MEASUREMENTS=[];

clear pub;
clear sub;
[pub, sub] = open_channel(5555, 5556);

init = 1;
while 1
    tic
    if ~init
        [message_type, message_payload] = get_message(sub);
        switch message_type
            case 'GET_GROUND_TRUTH',
                
                GET_GROUND_TRUTH = 1;
            case 'SET_GROUND_TRUTH',
                
                SET_GROUND_TRUTH = 1;
                NEW_GROUND_TRUTH = message_payload;
            case 'NEW_GROUND_TRUTH',
                
                NEW_GROUND_TRUTH = 1;
            case 'INITIALISE_ESTIMATOR',
                
                INITIALISE_ESTIMATOR = 1;
            case 'FUSE_MEASUREMENTS',
                
                FUSE_MEASUREMENTS = message_payload;
            case 'NEXT_STEP',
                
                NEXT_STEP = 1;
            case 'REQUEST_CURRENT_STATE',
                
                REQUEST_CURRENT_STATE = 1;
            case 'REQUEST_PREDICTION',
                
                REQUEST_PREDICTION = 1;
                PREDICT_N = message_payload;
            case 'NONE'
                BYPASS = 1;
                pause(0.05);
            otherwise,
                disp('INVALID COMMAND');
                MESSAGE = 'INVALID COMMAND';
        end
    else
        init = 0;
        BYPASS=1;
    end
    MESSAGE = 'fail';         
    if GET_GROUND_TRUTH
        disp('GET GROUND TRUTH');
        GET_GROUND_TRUTH = 0;
        MESSAGE.rad = rad;
        MESSAGE.KK = KK;
        MESSAGE.particle_vel.x = particle_vel.x;
        MESSAGE.particle_vel.y = particle_vel.y;
    end
    if SET_GROUND_TRUTH
        disp('SET GROUND TRUTH');
        SET_GROUND_TRUTH = 0;
        rad = NEW_GROUND_TRUTH.rad;
        KK = NEW_GROUND_TRUTH.KK;
        particle_vel = NEW_GROUND_TRUTH.particle_vel;
        [x,P]=initialise_KF(map_size,KK); % Initialise KF.
        tt=1;
        scale=100/(10+max(max(max(rad))));
        MESSAGE = 'ok';
    end
    if NEW_GROUND_TRUTH
        disp('NEW GROUND TRUTH');
        [rad,KK,particle_vel]=simulator_dirty_bomb(map_size,nsteps,sources,source_strength, ...
                         detonation,detonation_extent,wind_s,10,wind_b,K,rho,0);
        fprintf(1,'Ground truth generated.\n\n');
        save_rad(['ground_truth.txt'],rad);
        save('ground_truth','rad','KK','particle_vel','rho');
        [x,P]=initialise_KF(map_size,KK); % Initialise KF.
        tt=1;
        scale=100/(10+max(max(max(rad))));
        MESSAGE.rad = rad;
        MESSAGE.KK = KK;
        MESSAGE.particle_vel = particle_vel;
        NEW_GROUND_TRUTH=0;
    end;
    if INITIALISE_ESTIMATOR % set to 1 to reset estimator to initial state.
        disp('INITIALISE ESTIMATOR');
        [x,P]=initialise_KF(map_size,KK); % Initialise KF.
        tt=1;
        INITIALISE_ESTIMATOR=0;
        MESSAGE='ok';
    end;
    
    if REQUEST_CURRENT_STATE
        disp('CURRENT STATE');
           map_mean=exp(x(1:nstate))-1;
           EST_MEAN=reshape(map_mean,map_size(1),map_size(2));
        
           map_var=max(0,(exp(x(1:nstate))-1).^2).*max(0,diag(P(1:nstate,1:nstate)));
           EST_VAR=reshape(sqrt(map_var),map_size(1),map_size(2));
            MESSAGE.MEAN = min(scale*EST_MEAN,100);
            MESSAGE.VAR = scale^2*EST_VAR;
           REQUEST_CURRENT_STATE=0;
    end;
    
    if REQUEST_PREDICTION % set to N to predict ahead N steps.
        
        x_pred=x;
        P_pred=P;
        for pred_t=1:PREDICT_N,
            % Each bomb radiates a bit.
            for i=1:size(sources,2),
                if tt+pred_t>=detonation(i) & tt+pred_t<detonation(i)+detonation_extent
                    ind=sub2ind(map_size,sources(1,i),sources(2,i));
                    x_pred(ind)=log(exp(x_pred(ind))+source_strength(i));
                end;
            end;
            
            % Predict next state of radiation cloud.
            [x_pred,P_pred]=predict(x_pred,P_pred,map_size,K,wind_b,KK,rho);
        end
        map_mean=exp(x_pred(1:nstate))-1;
        PRED_MEAN=reshape(map_mean,map_size(1),map_size(2));
        
        map_var=max(0,(exp(x_pred(1:nstate))-1).^2).*max(0,diag(P_pred(1:nstate,1:nstate)));
        PRED_VAR=reshape(sqrt(map_var),map_size(1),map_size(2));
        
        MESSAGE.MEAN = PRED_MEAN;
        MESSAGE.VAR = PRED_VAR;
        REQUEST_PREDICTION=0;
    end;

    if NEXT_STEP 
        disp('NEXT STEP');
        tt=tt+1;
        fprintf(1,'*** Frame: %d\n',tt);
    
        % Each bomb radiates a bit.
        for i=1:size(sources,2),
            if tt>=detonation(i) & tt<detonation(i)+detonation_extent
                ind=sub2ind(map_size,sources(1,i),sources(2,i));
                x(ind)=log(exp(x(ind))+source_strength(i));
            end;
        end;

        % Predict next state of radiation cloud.
        [x,P]=predict(x,P,map_size,K,wind_b,KK,rho);

        NEXT_STEP=0;
        MESSAGE='ok';
    end;
    
    if ~isempty(FUSE_MEASUREMENTS),
        disp('FUSE MEASUREMENTS');
        id=FUSE_MEASUREMENTS(:,1);
        xloc=FUSE_MEASUREMENTS(:,2);
        yloc=FUSE_MEASUREMENTS(:,3);
        nid=length(id);
        
        GEIGER=zeros(nid,2);

        for i=1:nid,
            %xloc(i) and yloc(i) are coordinates of monitor i.
            obs(1,1)=rad(xloc(i),yloc(i),tt)+wd_sigma*randn;
            
            ind=yloc(i)*nx+xloc(i);
            obs(2,1)=wind_b+particle_vel.x(ind,tt)+gc_sigma*randn;
            obs(3,1)=wind_b+particle_vel.y(ind,tt)+gc_sigma*randn;
    
            GEIGER(i,1)=id(i);
            GEIGER(i,2)=obs(1,1);
            
            % Fold monitor observations into radiation and wind maps.
            [x,P]=fuse(x,P,map_size,xloc(i),yloc(i),obs,[1e10 gc_sigma^2 ...
                           gc_sigma^2],wind_b);
        end;
        FUSE_MEASUREMENTS=[];
        MESSAGE=min(scale*GEIGER,100);
        disp(GEIGER)
    end;

    map_mean=exp(x(1:nstate))-1;
    map_mean=reshape(map_mean,map_size(1),map_size(2));
        
    map_var=max(0,(exp(x(1:nstate))-1).^2).*max(0,diag(P(1:nstate,1:nstate)));
    map_var=reshape(sqrt(map_var),map_size(1),map_size(2));

    rad(:,:,tt)=rad(nx:-1:1,:,tt);
    map_mean=max(0,map_mean(nx:-1:1,:));   % RADIATION MAP MEAN ESTIMATE.
    map_var=max(0,map_var(nx:-1:1,:));     % RADIATION MAP VARIANCE.
    
    wind_var_x=diag(P(nstate+1:2*nstate,nstate+1:2*nstate));
    wind_var_y=diag(P(2*nstate+1:end,2*nstate+1:end));
    wind_var=wind_var_x+wind_var_y;
    wv=reshape(sqrt(wind_var),map_size(1),map_size(2));
    wv=wv(nx:-1:1,:);
    
   if draw
        hh=figure(1);
        set(hh,'Position',[10 10 1200 700]);
        clf
    
        subplot(2,3,1);
        h=surf(min(3,max(0,rot90(rad(:,:,tt),-1))));
        view([0 90]);
        caxis([0 1]);
        shading interp
        hold on;
        title('Ground Truth ','FontSize',20);
        axis([1 nx 1 ny]);
        axis square
        axis off
        for i=1:nagents,
            plotcross(xloc(i),yloc(i));
        end;
    
        subplot(2,3,2);
        h=surf(min(3,rot90(map_mean,-1)));
        view([0 90]);
        caxis([0 1]);
        shading interp
        hold on;
        title('Prediction: Mean ','FontSize',20);
        axis([1 nx 1 ny])
        axis square
        axis off
        colorbar;
        set(gca,'FontSize',20);
        for i=1:nagents,
            plotcross(xloc(i),yloc(i));
        end;

        subplot(2,3,3);
        h=surf(min(1,rot90(map_var,-1)));
        view([0 90]);
        caxis([0 1]);
        shading interp
        hold on;
        title('Prediction: Standard Dev. ','FontSize',20);
        axis([1 nx 1 ny])
        axis square
        axis off
        colorbar;
        set(gca,'FontSize',20);
        for i=1:nagents,
            plotcross(xloc(i),yloc(i));
        end;

        subplot(2,3,4);
        i=0;
        for yy=1:ny,
            for xx=1:nx,
                i=i+1;
                plot([xx xx+particle_vel.x(i,tt)+wind_b],[yy yy+particle_vel.y(i,tt)+wind_b],'k-');,
                hold on;
            end;
        end;
        title('Ground Truth ','FontSize',20);
        axis square
        axis tight
        axis off

        text(-12,8, '{\bf WIND}                            {\bf RADIATION}','FontSize',30,'rotation',90);

        subplot(2,3,5);
        i=0;
        for yy=1:ny,
            for xx=1:nx,
                i=i+1;
                plot([xx xx+wind_b+x(nstate+i)],[yy yy+(wind_b+x(2*nstate+i))],'k-');,
                hold on;
            end;
        end;
        title('Prediction: Mean ','FontSize',20);
        axis square
        axis tight
        axis off
    
        subplot(2,3,6);
        h=surf(min(1,max(0,rot90(wv,-1))));
        hold on;
        view([0 90]);
        caxis([0 1]);
        shading interp
        title('Prediction: Standard Dev. ','FontSize',20);
        axis square
        axis tight
        axis off
        colorbar
        set(gca,'FontSize',20);
    
        drawnow 
    end;
    
    
    if BYPASS
        BYPASS=0;
    else
        disp('SENDING');
        send_message(pub, message_type, MESSAGE);
        toc
    end
end


