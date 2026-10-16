clc; clear; close all;

%% System identification

% Helicrane loop function, from "primer_uporabe_helicrane.m"
function y = helicrane_it(u, it, x0, y0)
    x = x0;
    y(:, 1) = y0;
    for i = 1:it-1
        Fm = u(i);
        [fi_ fip_] = helicrane(Fm,x);
        x = [fip_ fi_];
        y(:, i+1) = [fi_ fip_];
    end
end

% Training signal
u_train = [0.1*ones(1, 1000), ...
    1.4*prbs(14)', ...
    0.7*ones(1, 1000), ...
    0.7*(1 + chirp(0:0.01:100, 0, 99, 5))];
it_train = length(u_train);
y_train = helicrane_it(u_train, it_train, [0 0], [0 0]);

% Congregating data into one array for NARX training
trainingData = sort([u_train(1 : end-1)', y_train(1, 1:end-1)', y_train(1, 2: end)']); 

% Visualizing
figure;
plot(0.01*(1:length(u_train)), u_train);
title("Input data");
grid on;
xlabel("Time (s)");
ylabel("Input amplitude");

figure;
plot(0.01*(1:length(u_train)), y_train(1, :));
grid on;
legend('Input', 'Y');
title('PRBS Identification');
xlabel("Time (s)");
ylabel("Output amplitude");

% Observations :
% Bounds = [0 1.477]
% Operating point = 0.7385

function psi = computePsi(u, y, n_order, delay)
    Nsys = length(u);
    psi = [];
    for j = 1:n_order %U Fetching
        psi = [psi, u(n_order -j + 1 : Nsys - j - 1 - delay)'];
    end
    for i = 1:n_order %Y fetching
        psi = [psi, y(n_order + delay -i + 1 : Nsys - i - 1)];
    end
    
end

function [psi, output] = generate_data_set(Fm, n)
    % Fm ~ [lower bound, higher bound];
    sp = 1;
    input = [Fm(1)*zeros(1, 1000)'; Fm(1)+ (Fm(2) - Fm(1))*prbs(n); Fm(1)+ (Fm(2) - Fm(1))*chirp(0:0.01:10, 0, 9, 10)';Fm(2)*ones(1, 500)'];
    %input = [linspace(Fm(1), Fm(2), n)'];
    %input = [Fm(1)*zeros(1000, 1); clip(Fm(1) + sqrt(Fm(2) - Fm(1))*randn(10000, 1),Fm(1),Fm(2))];
    %input = sort((1.4/2)+ sqrt(1)*randn(1, n));
    output = helicrane_it(input, length(input), [0, 0], [0, 0]);
    
    %input = input(input > Fm(1) & input < Fm(2))';
    %output = output(input > Fm(1) & input < Fm(2))';
    
    psi = computePsi(input(sp:end)', output(1, sp:end)', 2, 0);
    %psi(:, 1:2) = psi(:, 1:2) - Fm(1);
    %psi(:, 3:4) = psi(:, 3:4) - 0; % min(psi(:, 3:4), [], 'all');
    output = (output(1, sp+3:end))';% - min(output, [], 'all'))';
end


%{
% FM = 0.7385 & X0 = [n(t) n(t)]
UZ3 = [sort(1000*abs(randn([2 10000])))];
%YZ3 = helicrane_it(0.7385*ones([1 10000]), 10000, UZ3, 0);
YZ3 = zeros([2 10000]);
for i=1:10000
    %disp(UZ3(:, i));
    tmp_y = helicrane_it(0.7385*ones([1 1000]), 1000, UZ3(:, i), [0 0]);
    YZ3(:, i) = tmp_y(end);
end
%}

% Identification signal
% step + prbs at different zones
function sig = create_ident_signal(lb, ub, step, n)
    n_iter = round((ub-lb)/step) +1 ;
    sig = [];
    for i=1:n_iter
        sig = [sig, (i-1)*step*ones(1, n) + lb];
        sig = [sig, step*prbs(9)' + (i-1)*step+lb];
    end
    sig = [sig, (ub+step)*ones(1, n)];
end

function hsig = extract_ratio(u, y, n)
    n_step = round(length(u)/n);
    hsig = [0, 0];
    for j=1:(n_step-1)

        disp(mean(y(2 + j*n: (j+1)*n - 1)));
        disp(mean(u(2 + j*n: (j+1)*n -1)));
        tmp_h = mean(y(1 + j*n: (j+1)*n ));
        hsig = [hsig; mean(u(2 + j*n: (j+1)*n - 1)), tmp_h];
    end
end
UZ3 = create_ident_signal(0, 1.35, 0.001, 500);
%UZ3 = sort((1.4/2)+ sqrt(1)*randn(1, 20000));

YZ3 = helicrane_it(UZ3, length(UZ3), [0, 0], [0, 0]);

t_ident = 0.01*(1:length(UZ3));

hz3 = extract_ratio(UZ3, YZ3(1, :), 500 + 511);

figure;
title('Random Sorted Identification');
hold on;
plot(t_ident, 50*UZ3(1, :));
plot(t_ident, YZ3(1, :), 'LineWidth', 2.0);
grid on;
legend('FI', 'FIP');

figure;
scatter(hz3(:, 1), hz3(:, 2));
grid on;
% Observations for X0 = [n(t) n(t)]
% Negligeable impact on result, about 1e-5
%}

%% Neural network training
%{
% Step 1: Define the NARX network
inputDelays = [1:2];  % Input delays
feedbackDelays = [1:2];  % Feedback delays
hiddenLayerSize = 10;  % Number of neurons in the hidden layer

narxNet = narxnet(inputDelays, feedbackDelays, hiddenLayerSize);

% Step 2: Configure the network
narxNet.divideFcn = '';
narxNet.trainParam.min_grad = 1e-6;


% Prepare the data for training
[Xs, Xi, Ai, Ts] = preparets(narxNet, num2cell(u_train), {}, num2cell(y_train(1,:)));
%[Xs, Xi, Ai, Ts] = preparets(narxNet,utest1,{},ytest1);

% Step 3: Configure the test signal
u_test = [0.7*ones(1, 1000), linspace(0.7, 1.4, 1000), ...
    1.4*ones(1, 1000), linspace(1.4, 0, 1000), 0*ones(1, 1000), ...
    linspace(0, 0.7, 1000), 0.7*ones(1, 2000), ...
    0.7*(1+ chirp(1:0.01:100, 0, 100, 2))];
y_test = helicrane_it(u_test, length(u_test), [0 0], [0 0]);

% Step 4: Train the network

%u_train = (u_train - mean(u_train))./std(u_train);
%y_train = (y_train - mean(y_train))./std(y_train);

% Step 4.1: Train the network
narxNet = train(narxNet, Xs, Ts, Xi, Ai);
%narxNet = load('narxNet.mat', 'narxNet');
% Step 5: Evaluate the network

% Step 6: Prepare the data for testing
[Xs_test, Xi_test, Ai_test, Ts_test] = preparets(narxNet, num2cell(u_test), {}, num2cell(y_test(1, :)));

% Simulate the network on test data
y_test_pred = narxNet(Xs_test, Xi_test, Ai_test);

% Convert cell arrays to numeric arrays for evaluation
y_test_pred = cell2mat(y_test_pred);
y_test = cell2mat(Ts_test);

% Calculate Mean Squared Error (MSE) for testing
mse_test = mean((y_test_pred - y_test).^2);
fprintf('Test MSE: %f\n', mse_test);

% Step 4.3: Visualize the network response
figure;
plot(0.01*(1:length(y_test(1, :))), y_test(1, :)); hold on;
plot(0.01*(1:length(y_test(1, :))), y_test_pred(1, :));
grid on;
xlabel("Time (s)");
ylabel("Output");
title("Visual comparison")
legend("Helicrane", "NARX Model");

figure;
plot(0.01*(1:length(y_test(1, :))), abs(y_test(1, :) - y_test_pred(1, :)), 'r');
grid on;
title("Error plot between helicrane and model");
xlabel("Time (s)");
ylabel("Output error");
%}
%% Takagi-Sugeno fuzzy modelization

% Creates a new Sugeno-type fuzzy inference system
fis = sugfis('Name', 'nlin_system');

% Defines the input and output variables
fis = addInput(fis, [0 1.4], 'Name', 'Fm');
fis = addInput(fis, [0 1.4], 'Name', 'Fmk1');
fis = addInput(fis, [0, 1.4], 'Name', 'Fmk2');
fis = addInput(fis, [0 99], 'Name', 'Yk1');
fis = addInput(fis, [0 99], 'Name', 'Yk2');
fis = addOutput(fis, [0 99], 'Name', 'Y');

% Defines the membership functions
% gbellmf[a, b, c] : a = width; b = shape of curve; c = center
%{
fis = addMF(fis, 'Fm', 'trapmf', [0, 0, 0.7, 0.71], 'Name', 'S1');
fis = addMF(fis, 'Fm', 'trapmf', [0.7, 0.71, 1.05, 1.06], 'Name', 'S2');
fis = addMF(fis, 'Fm', 'trapmf', [1.05, 1.06, 1.25, 1.26], 'Name', 'S3');
fis = addMF(fis, 'Fm', 'trapmf', [1.25, 1.26, 1.36, 1.37], 'Name', 'S4');
fis = addMF(fis, 'Fm', 'trapmf', [1.36, 1.37, 1.4, 1.4], 'Name', 'S5');
%}

fis = addMF(fis, 'Fm', 'trimf', [0, 0, 0.7], 'Name', 'S1');
fis = addMF(fis, 'Fm', 'trimf', [0, 0.7, 1.25], 'Name', 'S2');
fis = addMF(fis, 'Fm', 'trimf', [0.7, 1.25, 1.36], 'Name', 'S3');
fis = addMF(fis, 'Fm', 'trimf', [1.25, 1.36, 1.4], 'Name', 'S4');
fis = addMF(fis, 'Fm', 'trimf', [1.36, 1.4, 1.4], 'Name', 'S5');
%}

% Define the fuzzy rules
gain = 1.41;
gain2 = 1.001;
fis = addMF(fis, 'Y', 'linear', [2.2578   -0.9302    0.9801   -0.0099 0], 'Name', 'Eq1');
rule1 = "If Fm is S1 then Y is Eq1";

fis = addMF(fis, 'Y', 'linear', [2.2804   -0.4895    0.9703   -0.0100  0], 'Name', 'Eq2');
rule2 = "If Fm is S2 then Y is Eq2";

fis = addMF(fis, 'Y', 'linear', [3.0970   -1.1020    0.9745   -0.0101  0], 'Name', 'Eq3');
rule3 = "If Fm is S3 then Y is Eq3";

fis = addMF(fis, 'Y', 'linear', [1.8892   -0.0393    0.9693   -0.0001  0], 'Name', 'Eq4');
rule4 = "If Fm is S4 then Y is Eq4";

fis = addMF(fis, 'Y', 'linear', [2.1192   -0.2312    0.9746   -0.0001 0], 'Name', 'Eq5');
rule5 = "If Fm is S5 then Y is Eq5";

fis = addRule(fis, [rule1; rule2; rule3; rule4; rule5]);

%{
% Use anfis to train the FIS
anfisOpt = anfisOptions();
%anfisOpt.InitialFIS = fis;
anfisOpt.EpochNumber = 100; % Number of training epochs
anfisOpt.DisplayANFISInformation = 1;
anfisOpt.DisplayErrorValues = 1;
anfisOpt.DisplayStepSize = 1;
anfisOpt.DisplayFinalResults = 1;
anfisOpt.OptimizationMethod = 1;

% Train the FIS
[Utrain, Ytrain] = generate_data_set([0.0, 1.4], 15);

fisOptions = genfisOptions('GridPartition');
fisOptions.NumMembershipFunctions = 4;
fisOptions.InputMembershipFunctionType = 'trimf';
fisOptions.OutputMembershipFunctionType = 'linear';
fisin = genfis(Utrain,Ytrain,fisOptions);

[in,out,rule] = getTunableSettings(fisin);
fis = tunefis(fisin,[in;out],Utrain,Ytrain,tunefisOptions(Method="anfis"));
%}
%[fis, trainError, stepSize] = anfis([Utrain, Ytrain], anfisOptions(InitialFIS = fisin));

% Simulate the fuzzy inference system
input = [1];
output = evalfis(fis, input);

disp(['Output: ', num2str(output)]);

figure;
gensurf(fis);
grid on;

figure;
plotmf(fis, 'input', 1);
grid on;


function y = helicrane_ts_it(u, it, y0, fis)
    y = y0;
    for i=1:(it-1)
        if i == 1
            y = [y; clip(evalfis(fis, [u(i); 0; 0; 0]), 0, 99)];
        elseif i == 2
            y = [y; clip(evalfis(fis, [u(i); u(i-1); y(i-1); 0]), 0, 99)];
        else
            y = [y; clip(evalfis(fis, [u(i); u(i-1); y(i-1); y(i-2)]), 0, 99)];
        end
    end
end

u_val = [0.7*ones(1, 1000), linspace(0.7, 1.4, 1000), ...
    1.4*ones(1, 1000), linspace(1.4, 0, 1000), 0*ones(1, 1000), ...
    linspace(0, 0.7, 1000), 0.7*ones(1, 2000), ...
    0.7*(1+ chirp(1:0.01:100, 0, 100, 2))];
%u_val = [(0.01)*ones(1, 500)];
y_val = helicrane_it(u_val, length(u_val), [0, 0], [0, 0]);
y_fuzzy_val = helicrane_ts_it(u_val, length(u_val), 0, fis);



figure;
%plot(u_val); hold on;
plot(y_val(1, :)'); hold on;
plot(y_fuzzy_val);
grid on;
legend();



figure;
plot(abs(y_val(1, :)' - y_fuzzy_val));
grid on;
legend();

figure;
%plot(u_val); hold on;
plot(0.01*(1:length(y_test_pred)), y_test_pred); hold on;
plot(0.01*(1:length(y_fuzzy_val)), y_fuzzy_val);
grid on;
legend("NARX", "Fuzzy");
title("NARX VS Fuzzy models");
xlabel("Time (s)");
ylabel("Output");

% FFT

G_fuzzy = fft(y_fuzzy_val')./fft(u_val);
G_heli = fft(y_val(1, :))./fft(u_val);
F = 1/(length(u_val) * 0.01) * (1:length(u_val))'-0.1;


figure;
subplot(2, 1, 1);
semilogx(F, 20*log10(abs(G_heli))); hold on;
semilogx(F, 20*log10(abs(G_fuzzy)));
grid on;
legend();

subplot(2, 1, 2);
semilogx(F, unwrap(angle(G_heli))); hold on;
semilogx(F, unwrap(angle(G_fuzzy)));
grid on;
legend();

