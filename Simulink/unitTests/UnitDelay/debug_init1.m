


%% Time Steps and Rates
bio_sim_rate = 100; % Hz
bio_cnt_rate = 5; % Hz

bio_sim_step_size = 1/bio_sim_rate;
bio_cnt_step_size = 1/bio_cnt_rate;

bio_step_size = bio_sim_step_size;
sim_duration = 2000;
% bio_start_time = 86400*0.4;
bio_start_time = 0;
bio_stop_time = bio_start_time + sim_duration;

%% Set up Buses
debug_buses

%% Constants
timestep = bio_cnt_step_size;
dt = timestep;
solver_dt = bio_sim_step_size; %off board sim timestep; wheels operate on discrete transfer function at 200 Hz so 0.005 sec is chosen for this reason

dec_plot = 100; %decimation for plotting

% Seed the random number generator to get repeatable results.
rng(32316);

mode = uint8(1);


%commanded quaternion
q_com = [0 0 0 1]';


SM_spin_axis = [-1;0;0];
SM_rate = 0.2*pi/180; %target spin rate
SM_rate_vec = SM_spin_axis*SM_rate; %target vector

gyro_LPF_on = uint8(0);

if mode > 2 && mode < 5
    KF_enable = uint8(1);
else
    KF_enable = uint8(0);
end

st_status = uint8(3);

eci_state_msg_IC = Simulink.Bus.createMATLABStruct('ECI_state_msg');

%% OFSW Init Files
%need to run these before sim_init.m
load('state_15day_lite');
%load orbits from 15-315 days lite version (1000 sec timestep)
load('state_15to550day_lite');

JD = cat(2,JDlite,JDlite2);
X_Eph = cat(1,X_Ephlite,X_Ephlite2);
rBio = cat(1,rBiolite,rBiolite2)';


rS = X_Eph(:,2:4)';
rE = X_Eph(:,8:10)';
rM = X_Eph(:,14:16)';

au = 149597870.699626200;
%for i = 1:length(JD)-1
for i = 1:100
    timeElap(i) = (JD(i) - JD(1))*86400;
    %Sun in ECI
    rS_ECI(:,i) = rS(:,i);% - rE(:,i);
    %Moon in ECI
    rM_ECI(:,i) = rM(:,i);% - rE(:,i);
    %s/c in ECI
    %rBio_ECI(:,i) = rBio(:,i) - rE(:,i);
    rBio_ECI(:,i) = rBio(:,i);
    %velocity of s/c in ECI
    %vBio_ECI(:,i) = ((rBio(:,i+1) - rE(:,i+1)) - (rBio(:,i) - rE(:,i)))/(JD(i+1) - JD(i));
    vBio_ECI(:,i) = (rBio(:,i+1) - rBio(:,i))/(JD(i+1) - JD(i));
    %s/c to Sun in ECI
    sun_vec_ECI(:,i) = rBio_ECI(:,i) - rS_ECI(:,i);
    %s/c to Moon in ECI
    moon_vec_ECI(:,i) = rBio_ECI(:,i) - rM_ECI(:,i);
    
    rBio_sun_x(i) = rBio(1,i)/norm(rBio(:,i));
    rBio_sun_y(i) = rBio(2,i)/norm(rBio(:,i));
    rBio_sun_z(i) = rBio(3,i)/norm(rBio(:,i));
    vBio_ECI_x(i) = vBio_ECI(1,i)/norm(vBio_ECI(:,i));
    vBio_ECI_y(i) = vBio_ECI(2,i)/norm(vBio_ECI(:,i));
    vBio_ECI_z(i) = vBio_ECI(3,i)/norm(vBio_ECI(:,i));
    moon_vec_x(i) = moon_vec_ECI(1,i);
    moon_vec_y(i) = moon_vec_ECI(2,i);
    moon_vec_z(i) = moon_vec_ECI(3,i);
end

R_xact2body = [0 -1 0; 0 0 1; -1 0 0]; % 
quat_xact2body = DCM_to_quat(R_xact2body);
R_body2xact = R_xact2body'; % Checked JCF, 2/21/17
quat_body2xact = DCM_to_quat(R_body2xact);

%estimated misalignment of xact (from nominal body to actual)
R_mis_xact_est_body = eye(3);
quat_mis_xact_est_body = [0;0;0;1];

%XACT to IMU rotation is given by the MICD
R_xact2imu = [0 1 0; -1 0 0; 0 0 1]; % Checked JCF, 2/21/17
R_imu2xact = R_xact2imu'; % Checked JCF, 2/21/17

%XACT to star tracker rotation is given by the MICD
R_xact2tracker = [0 1 0; sind(10) 0 cosd(10); cosd(10) 0 -sind(10)]; % Checked JCF, 2/21/17
quat_xact2tracker = DCM_to_quat(R_xact2tracker);
R_tracker2xact = R_xact2tracker'; % Checked JCF, 2/21/17
quat_tracker2xact = DCM_to_quat(R_tracker2xact);

%XACT to wheels rotation is given by the MICD
R_xact2wheels = [1 0 0; 0 -1 0; 0 0 -1]; % Checked JCF, 2/21/17
R_wheels2xact = R_xact2wheels'; % Checked JCF, 2/21/17


%Time
met_sec_LSB = 0.2; % Count to sec


%gyro
%low pass filter for gyro
f = 2*pi*0.5;
%f = 1;
gyro_lp_num = 1 - exp(-f*dt);
gyro_lp_den = [1 -exp(-f*dt)];


%gyro LSB conversion
gyro_rate_LSB = 1e-5; %counts to rad/sec


%star tracker
ST_quat_LSB = 4.88e-10; %counts to quat


%Sun sensors -- Solar MEMS D60 digital sun sensor
%5 sun sensors on the following faces:
%SS1 on -Z face
%SS2 on +Z face
%SS3 on +Y face
%SS4 on -Y face
%SS5 on -X face
%orient each sun sensor with a rotation from body axes to sensor axes
R_SS1_sens2body = [0 -1 0; -1 0 0; 0 0 -1]; % -Z face
R_SS2_sens2body = [0 -1 0; 1 0 0; 0 0 1];   % +Z face
R_SS3_sens2body = [0 -1 0; 0 0 1; -1 0 0];  % +Y face
R_SS4_sens2body = [0 1 0; 0 0 -1; -1 0 0];  % -Y face
R_SS5_sens2body = [0 0 -1; 0 -1 0; -1 0 0]; % -X face
%estimated sun sensor misalignment in body frame (from body ideal to body
%actual)
R_mis_SS1_body_est = eye(3);
R_mis_SS2_body_est = eye(3);
R_mis_SS3_body_est = eye(3);
R_mis_SS4_body_est = eye(3);
R_mis_SS5_body_est = eye(3);

%need to read raw voltages to determine if sun sensor is in view
SS_min_Vthreshold = 0.1; % Min voltage, mainly in place to reject 0.0 volts
SS_valid_Vthreshold = 3.0; % Voltage below which a sensor is used
%-------------------------------------------------------------------------%


%-------------------------Kalman filter parameters------------------------%
gyro_noise_est = (0.1*pi/180/sqrt(3600))^2;
sigma_r = sqrt(gyro_noise_est);%/sqrt(dt);
sigma_w = 0.1*pi/180/3600;%*sqrt(dt);

%sigma_w = 5.1*pi/180/3600;

ST_noise = (40/3600*pi/180)^2; %variance - rad
sigma_meas = sqrt(ST_noise);
sigma_S = 1*pi/180;
sigma_ss = sigma_S/3;

%covariance of the residual
R_st = diag([sigma_meas^2 sigma_meas^2 sigma_meas^2 sigma_meas^2]);
R_ss = diag([sigma_ss^2 sigma_ss^2 sigma_ss^2]);

est_init_gyro_bias = [0;0;0];

Pcc0 = diag([(.05*pi/360)^2 (.05*pi/360)^2 (.05*pi/360)^2]); %Attitude error covariance
Pgg0 = diag([(.5*pi/180)^2 (.5*pi/180)^2 (.5*pi/180)^2]); %Gyro bias error covariance
Pk0 = blkdiag(Pcc0, Pgg0); %initial covariance estimate

%parameters for checking and handling positive definiteness of covariance
pd_eps = 1e-6;
pd_zero = 1e-10;

%threshold for swithching to safe quaternion integration for small rates
wmag_thresh = 1e-6;
%-------------------------------------------------------------------------%

%momentum limit for triggering need for safe mode
max_momentum_limit = 0.01; %this is equal to the momentum of a single wheel spinning at 4000 RPM

s_hat_o = [-1;0;0]; %sun vector in orbit frame used for multiplying q_LVLH_2_body*s_hat_o for sun vector estimation in nominal mode; also input to EKF
%[-1 0 0] means sun vector is defined from spacecraft to sun

%low pass filter for wx estimation in safe mode
f = .005;
est_wx_lpf_num = 1 - exp(-f*dt);
est_wx_lpf_den = [1 -exp(-f*dt)];

%height of H matrix for inertia estimation
t_begin_maneuver = 7;
t_end_maneuver = 140;
H_mat_height = 3*(t_end_maneuver - t_begin_maneuver)/0.2;
% est_init;
% acs_init;
% pcs_init;
% 
% %% Sim Init Files
% csu_time_init
% sim_init;