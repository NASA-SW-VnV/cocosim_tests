#!/bin/sh
/Users/hbourbou/Applications/MATLAB_R2017b.app/bin/matlab -nodisplay -r "try, addpath('/Users/hbourbou/Documents/babelfish/cocosim2'); start_cocosim; addpath('/Users/hbourbou/Documents/babelfish/cocosim_tests/scripts'); cd('/Users/hbourbou/Documents/babelfish/cocosim_tests/Simulink/unitTests'); test_all(pwd, [], 1); catch me, display(me.getReport()), end, exit;"