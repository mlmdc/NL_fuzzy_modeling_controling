clc; clear; close all;

%% Fuzzy model predictive functional controller

%% Takagi-Sugeno fuzzy modelization

function y = helicrane_ts_it(u, it, y0, fis)
    y = zeros(it, 1);
    y(1) = y0;
    y(2) = clip(evalfis(fis, [u(2), u(1), y(1), y(1)]), 0, 99);
    for i = 3:it
        y(i) = clip(evalfis(fis, [u(i), u(i-1), y(i-1), y(i-2)]), 0, 99);
    end
end
%}
load("fuzzy_data.mat");
%% Fuzzy to State Space 
% Local discrete models
z = tf('z', 0.01);
local_m1 = tf(model_weights(1, 1:2), [1, -model_weights(1, 3:4)],0.01);
local_m2 = tf(model_weights(2, 1:2), [1, -model_weights(2, 3:4)],0.01);
local_m3 = tf(model_weights(3, 1:2), [1, -model_weights(3, 3:4)],0.01);
local_m4 = tf(model_weights(4, 1:2), [1, -model_weights(4, 3:4)],0.01);
local_m5 = tf(model_weights(5, 1:2), [1, -model_weights(5, 3:4)],0.01);


figure;
stepplot(local_m1, local_m2, local_m3, local_m4, local_m5);
% State space representations
SS1 = ss(local_m1); R1 = centers(1, 1);
SS2 = ss(local_m2); R2 = centers(2, 1);
SS3 = ss(local_m3); R3 = centers(3, 1);
SS4 = ss(local_m4); R4 = centers(4, 1);
SS5 = ss(local_m5); R5 = centers(5, 1);
Rx = [R1; R2; R3; R4; R5];

%% Testing if models are the same
%{
u_test = [0.01*ones(1, 1000), 0.3*ones(1, 1000), 0.5*ones(1, 1000), 0.7*ones(1, 1000), 1.25*ones(1, 1000), 1.36*ones(1, 1000), 1.4*ones(1, 1000)];

y_fuzzy = helicrane_ts_it(u_test, length(u_test), 0, fis);
y_ss = fuzzy_ss_it(u_test, length(u_test), 0, SS1, SS2, SS3, SS4, SS5, Rx);

figure;
hold on;
plot(y_fuzzy); 
plot(y_ss);
grid on;
legend();
%}

%% Control functions

function [SSm, Rm] = computeSSm(u, SS1, SS2, SS3, SS4, SS5, Rx)
    % Constructing the membership
    mb = [trimf(u, [0, 0, 0.7]), ...          
          trimf(u, [0, 0.7, 1.25]), ...
          trimf(u, [0.7, 1.25, 1.36]), ...
          trimf(u, [1.25, 1.36, 1.4]), ...
          trimf(u, [1.36, 1.4, 1.4])];

    % Associating the local matrices following membership
    Am = mb(1)*SS1.A + mb(2)*SS2.A + mb(3)*SS3.A + mb(4)*SS4.A + mb(5)*SS5.A;
    Bm = mb(1)*SS1.B + mb(2)*SS2.B + mb(3)*SS3.B + mb(4)*SS4.B + mb(5)*SS5.B;
    Cm = mb(1)*SS1.C + mb(2)*SS2.C + mb(3)*SS3.C + mb(4)*SS4.C + mb(5)*SS5.C;
    Dm = mb(1)*SS1.D + mb(2)*SS2.D + mb(3)*SS3.D + mb(4)*SS4.D + mb(5)*SS5.D;

    % Global model
    SSm = ss(Am, Bm, Cm, Dm);
    Rm = mb(1)*Rx(1, :) + mb(2)*Rx(2, :) + mb(3)*Rx(3, :) + mb(4)*Rx(4, :) + mb(5)*Rx(5, :);
end

testSSm= computeSSm(1, SS1, SS2, SS3, SS4, SS5, Rx);

function y = fuzzy_ss_it(u, it, y0, SS1, SS2, SS3, SS4, SS5, Rx)
    ym = y0;
    y = ym;
    xm = [0; 0];
    for k=1:it
        [SSm, Rm] = computeSSm(u(k), SS1, SS2, SS3, SS4, SS5, Rx);
        [ym, xm] = computeSSVec(SSm, xm, u(k), [0, 1.4]');
        y = [y, ym];
    end
end

function [Y, X] = computeSSVec(SSx, Xk, u, Rm)
    X = SSx.A*Xk + SSx.B*u + Rm;
    Y = SSx.C*Xk;
end

function G0 = computeG0(SSx, H)
    % Separate lines for clarity
    X1X = ((SSx.A^H) - eye(size(SSx.A))+1e-9);
    X1X = X1X*((SSx.A - eye(size(SSx.A))+1e-9)^(-1));
    G0 = SSx.C*X1X*SSx.B;
end

function G = computeG(G0, SSx, H)
    G = ((G0+1e-9)^-1)*(eye(size(SSx.A)) - SSx.A^H);
end


function uk = computeUk(SSm, G, G0, Rx, wk, yp, ym, xm, Hor)
    uk = G*(wk - yp)+ ((G0+1e-9)^-1)*ym - ((G0+1e-9)^-1)*SSm.C * (SSm.A^Hor) * xm; %- (1/SSm.B)*[Rx; 0];
end

%% Controller parameters

% Reference 1st order system
ref_model_pole = -3*3;
Ar = exp(ref_model_pole*0.01);% # --> calculate pole in z-plane
Br = eye(size(Ar)) - Ar; % Equilibrate the system to be unitary
Cr = eye(size(Ar));
Dr = 0;
SSr = ss(Ar, Br, Cr, Dr); % Transformation at SSr

% Step response of the system 

figure;
[b, a] = ss2tf(Ar, Br, Cr, Dr);
step(tf(b, a, 0.01));


% Creating the input signal
u_sig = [0.5*ones(1, 1000)];
for j=0.6:0.1:1.0
    u_sig = [u_sig, j*ones(1, 1000)];
end
u_sig = [];
for j=0:0.1:1.3
    u_sig = [u_sig, j*ones(1, 1000)];
end
u_sig = 10*u_sig + 0.1*rand(size(u_sig)); %adding noise
u_len = length(u_sig);

% Max values & parameters
horizon = 80;
minU = 0;
maxU = 1.3;
maxDifferential = 0.5;

% Initial values
% Model
ym = 0;
xm = [0;0];

% Reference
yr = 0;
xr = 0;

% Helicrane process
xp = [0 0];
yp = 0;

% Fuzzy
SSm = ss();
Rm = 0;
uk = u_sig(1);

% Cumulative values
ref_cumul = zeros(u_len, 1);
proc_cumul = zeros(u_len, 1);
contr_cumul = zeros(u_len, 1);
uk_cumul = zeros(u_len+1, 1);

%% Main loop

for k=1:u_len
    % Local membership calculation
    [SSm, Rm] = computeSSm(uk, SS1, SS2, SS3, SS4, SS5, Rx);
    
    % State space vectors calculations
    [yr, xr] = computeSSVec(SSr, xr, u_sig(k), Rm);
    [ym, xm] = computeSSVec(SSm, xm, uk, Rm);%Rm');

    ref_cumul(k) = yr;
    contr_cumul(k) = ym;
    
    % Helicrane process computation
    
    [xp(1), xp(2)] = helicrane(uk, xp);
    xp = [xp(2), xp(1)];
    yp = xp(2);

    proc_cumul(k) = yp;
    

    % G, G0
    G0 = computeG0(SSm, horizon);
    G = computeG(G0, SSr, horizon);
    
    % Control law computation
    uk = computeUk(SSm, G, G0, Rm, yr, ym, ym, xm, horizon);
    
    % Differential limits
    %{
    if uk - uk_cumul(k) > maxDifferential % # limit the differential of the control 
        uk = uk_cumul(k) + maxDifferential;
    end
    if uk - uk_cumul(k) < -maxDifferential % # limit the differential of the control 
        uk = uk_cumul(k) - maxDifferential;
    end
    %}
    
    % Limiting the input
    if uk < minU
        uk = minU;
    elseif uk > maxU
        uk = maxU;
    end
    uk_cumul(k) = uk;
    
    
end

% Plot reference
figure;
plot(ref_cumul, LineWidth=2); hold on;
plot(contr_cumul);
plot(proc_cumul);
legend();
grid on;

% Command - Output comp.
figure;
plot(0.01*(1:length(u_sig)), u_sig, 'LineWidth', 2); hold on;
plot(0.01*(1:length(contr_cumul)),contr_cumul, 'LineWidth', 2);
grid on;
legend("Reference", "Control")
title("Controller output - reference");
xlabel("Time (s)");
ylabel("Output amplitude");

figure;
plot(0.01*(1:length(u_sig - contr_cumul')), u_sig - contr_cumul', 'LineWidth', 2); hold on;
%plot(0.01*(1:length(contr_cumul)),contr_cumul, 'LineWidth', 2);
grid on;
%legend("Reference", "Control")
title("Controller output - reference error");
xlabel("Time (s)");
ylabel("Output error amplitude");
