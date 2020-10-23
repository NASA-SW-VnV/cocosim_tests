


cellInfo = {
    { ...
         'command_state_msg' , ...
         '', ...
         sprintf(''), {  ...
               {  'q_com', 4, 'single', -1, 'real', 'Sample' }; ... 
               {  'sm_spin_axis', 3, 'single', -1, 'real', 'Sample' }; ... 
               {  'sm_rate_vec', 3, 'single', -1, 'real', 'Sample' }; ... 
               {  'man_wheel_speed', 3, 'single', -1, 'real', 'Sample' }; ... 
               {  'man_wheel_torq', 3, 'single', -1, 'real', 'Sample' }; ... 
               {  'man_gimbal_cmd', 1, 'int16', -1, 'real', 'Sample' }; ... 
               {  'man_prop_cmd', 8, 'uint16', -1, 'real', 'Sample' }; ... 
               {  'gyro_LPF_on', 1, 'uint8', -1, 'real', 'Sample' }; ... 
               {  'st_status', 1, 'uint8', -1, 'real', 'Sample' }; ... 
               {  'mode', 1, 'uint8', -1, 'real', 'Sample' }; ... 
               {  'KF_enable', 1, 'uint8', -1, 'real', 'Sample' }; ... 
               {  'bypass_acs', 3, 'uint8', -1, 'real', 'Sample' }; ... 
               {  'mm_flag', 1, 'uint8', -1, 'real', 'Sample' }; ... 
         }
    }
};
Simulink.Bus.cellToObject(cellInfo);

SampleTime = .2;   % Khanh made this up
dt = .2;             % Khanh made this up
dt = .2;

mode = uint8(1);


%commanded quaternion
q_com = [0 0 0 1]';

%safe mode spin axis and rate
%SM_spin_axis = [-sqrt(2)/2;0;sqrt(2)/2]; %target axis
SM_spin_axis = [-1;0;0];
SM_rate = 0.2*pi/180; %target spin rate
SM_rate_vec = SM_spin_axis*SM_rate; %target vector

%flag for using LPF on gyro
gyro_LPF_on = uint8(0);

%KF_enable flag: 1 for use EKF, 0 for bypass EKF
if mode > 2 && mode < 5
    KF_enable = uint8(1);% Kalman filter on
else
    KF_enable = uint8(0);
end

%st_status = 1 means star tracker and sun sensor used
%st_status = 2 means star tracker only
%st_status = 3 means sun sensor only
st_status = uint8(3);
