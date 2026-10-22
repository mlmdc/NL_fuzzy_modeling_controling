clc; clear; close all;

%% System identification

% Helicrane loop function, also demonstrated in "helicrane_simulation_example.m"
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


% Observations :
% Bounds = [0 1.355]
% Operating point = 0.7385


% Identification signal
% step + prbs at different zones
function sig = create_ident_signal(lb, ub, step, n)
    n_iter = round((ub-lb)/step) +1 ;
    sig = [];
    for i=1:n_iter
        sig = [sig, (i-1)*step*ones(1, n) + lb];
        sig = [sig, step*generate_prbs(10)' + (i-1)*step+lb];
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
UZ3 = create_ident_signal(0, 1.3, 0.05, 500);
UZ3 = UZ3 + 0.01*rand(size(UZ3));
%UZ3 = sort((1.4/2)+ sqrt(1)*randn(1, 20000));

YZ3 = helicrane_it(UZ3, length(UZ3), [0, 0], [0, 0]);

t_ident = 0.01*(1:length(UZ3));

hz3 = extract_ratio(UZ3, YZ3(1, :), 500 + 1023);

figure;
hold on;
plot(t_ident, YZ3(1, :), '.');
title("Y output signal for training");
xlabel("time (s)");
ylabel("Amplitude")
grid on;

figure;
hold on;
plot(t_ident, UZ3(1, :), '-.');
grid on;
title("U signal for training");
xlabel("time (s)");
ylabel("Amplitude")

function [mu, upsilon, Fi] = gustafson_kessel(X, c, m, epsilon, rmax)
% X: data matrix (n x d)
% c: number of clusters
% m: fuzziness parameter (typically 2)
% epsilon: stopping threshold (e.g., 1e-5)
% max_iter: maximum number of iterations

[n, d] = size(X);

% Initialize membership matrix randomly
mu = rand(n, c);
mu = mu ./ sum(mu, 2);

% Initialize
prev_U = zeros(n, c);
upsilon = zeros(c, d); %upsilon: cluster centers
Fi = zeros(d, d, c); %sigma: fuzzy covariance mat
I = eye(d);

for iter = 1:rmax
    % Update cluster centers
    for j = 1:c % for 1 to n_clusters
        murik = mu(:, j).^m; %murik is mu_ik^r
        upsilon(j, :) = sum(X .* murik, 1) / sum(murik); %epsilon = sum mu * X/sum mu
    end

    % Update covariance matrices and distance
    for j = 1:c
        murik = mu(:, j).^m;
        diff = X - upsilon(j, :);
        sigma = zeros(d);
        for i = 1:n %sum of all mur-1k * diff * diff^T
            sigma = sigma + murik(i) * (diff(i, :)' * diff(i, :));
        end
        sigma = sigma / sum(murik); %final computation
        % determinant normalization
        det_cov = det(sigma) + 10e-9; %avoid division by zero
        
        % Matrix of inner product
        Fi(:, :, j) = (det_cov)^(1/d) * pinv(sigma);
    end

    % Update distances and U
    Dik = zeros(n, c);
    for j = 1:c
        for i = 1:n
            diff = X(i, :) - upsilon(j, :); %distance error from cluster center to data
            Dik(i, j) = diff * Fi(:, :, j) * diff'; % distance vectors 
        end
    end
    Dik = max(Dik, 10e-9);  %Avoid division by zero
    tmp_mmbr = Dik.^(-1/(m-1));
    mu = tmp_mmbr ./ sum(tmp_mmbr, 2); %membership matrix

    % Check convergence
    if max(max(abs(mu - prev_U))) < epsilon
        break;
    end
    prev_U = mu;
end
end

% Parameters
c = 5; % number of clusters
m = 2.0; % fuzziness
epsilon = 1e-5; % convergence threshold
rmax = 100; % max iterations

[U, centers, covariances] = gustafson_kessel(hz3, c, m, epsilon, rmax);

% Re-order accordingly to the position of the center, so as to make it
% clear

[centers, idx] = sort(centers, 1);

% Reorder B and C using the sort index
U = U(:, idx(:, 1));
covariances = covariances(:, :, idx(:, 1));

% visualising
figure;
[~, labels] = max(U, [], 2);
gscatter(hz3(:,1), hz3(:,2), labels);
hold on;
plot(centers(:,1), centers(:,2), 'kx', 'MarkerSize', 15, 'LineWidth', 2);
title('Gustafson-Kessel Clustering');

% gaussian membership
gauss_mf = zeros;
gauss_params = [];
[~, repart] = max(U, [], 2);
for i=1:5
    x_dim = hz3(:, 1);
    u_j = U(:, i);

    % Estimate sigma from activation function vector
    sigma_jd = sqrt(sum(u_j .* (x_dim - c_jd).^2) / sum(u_j));
    
    params = [sigma_jd, centers(i, 1)]; 
    gauss_params = [gauss_params; params]; %Accumulate parameters
    gauss_mf = gaussmf(hz3(:, 1), params); %produce the gaussmf corresponding function
    
    % System id. parameters
    m = 2; % order
    d = 2; % delay
    lambda = 1e-3; %reg. parameter

    interp_points = linspace(min(UZ3), max(UZ3), length(UZ3(3:end-d)));
    W = interp1(hz3(:, 1), (gauss_mf/max(gauss_mf))+10e-9, interp_points); %Interpolate gaussmf and activation
    W(isnan(W)) = 0; % Replace NaN with 0 (equivalent meaning)
    W = diag(W); % Diag to match X shape
    
    
    t_start = d + 2;
    N = length(UZ3);
    % X regressor composition
    X = [UZ3(t_start-d:N-1-d)', UZ3(t_start-d-1:N-m-d)', -YZ3(1, 2:N-1-d)', -YZ3(1, 1:N-2-d)', ones(N-2-d, 1)];
    
    % WLS with regularization
    theta_hat = pinv(X'*W*X+ lambda*eye(size(X,2)))*X'*W*YZ3(1, m+1:end-d)';
    
    % reverse sign for Y
    theta_hat(3:4, 1) = -theta_hat(3:4, 1); %reversing weights for Y contributions
    
    model_weights(i,:) = theta_hat';
    
end
figure;
hold on;
for i=1:5
    numer = model_weights(i, 1:2);
    den = [1, -model_weights(i, 3:4)];
    tmp_tf = tf(numer, den, 0.01);
    stepplot(tmp_tf);
    
end
legend("1", "2", "3", "4", "5");
%% Neural network training

% Step 1: Define the NARX network
inputDelays = [1:2];  % Input delays
feedbackDelays = [1:2];  % Feedback delays
hiddenLayerSize = 10;  % Number of neurons in the hidden layer

narxNet = narxnet(inputDelays, feedbackDelays, hiddenLayerSize);

% Step 2: Configure the network
narxNet.divideFcn = '';
narxNet.trainParam.min_grad = 1e-6;


% Prepare the data for training
[Xs, Xi, Ai, Ts] = preparets(narxNet, num2cell(UZ3), {}, num2cell(YZ3(1,:)));
%[Xs, Xi, Ai, Ts] = preparets(narxNet,utest1,{},ytest1);

% Step 3: Configure the test signal
u_test = [];
for j=0:0.1:1.3
    u_test = [u_test, j*ones(1, 1000)];
end
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

%% Takagi-Sugeno fuzzy modelization

% Creates a new Sugeno-type fuzzy inference system
fis = sugfis('Name', 'nlin_system');

% Defines the input and output variables
fis = addInput(fis, [0 1.3], 'Name', 'Fm');
fis = addInput(fis, [0 1.3], 'Name', 'Fmk1');
fis = addInput(fis, [0 99], 'Name', 'Yk1');
fis = addInput(fis, [0 99], 'Name', 'Yk2');
fis = addOutput(fis, [0 99], 'Name', 'Y');

% Defines the membership functions
% Membership functions corresponding to the cluster
fis = addMF(fis, 'Fm', 'gaussmf', gauss_params(1, :), 'Name', 'S1');
fis = addMF(fis, 'Fm', 'gaussmf', gauss_params(2, :), 'Name', 'S2');
fis = addMF(fis, 'Fm', 'gaussmf', gauss_params(3, :), 'Name', 'S3');
fis = addMF(fis, 'Fm', 'gaussmf', gauss_params(4, :), 'Name', 'S4');
fis = addMF(fis, 'Fm', 'gaussmf', gauss_params(5, :), 'Name', 'S5');

% Define the fuzzy rules
fis = addMF(fis, 'Y', 'linear', model_weights(1, :), 'Name', 'Eq1');
rule1 = "If Fm is S1 then Y is Eq1";

fis = addMF(fis, 'Y', 'linear', model_weights(2, :), 'Name', 'Eq2');
rule2 = "If Fm is S2 then Y is Eq2";

fis = addMF(fis, 'Y', 'linear', model_weights(3, :), 'Name', 'Eq3');
rule3 = "If Fm is S3 then Y is Eq3";

fis = addMF(fis, 'Y', 'linear', model_weights(4, :), 'Name', 'Eq4');
rule4 = "If Fm is S4 then Y is Eq4";

fis = addMF(fis, 'Y', 'linear', model_weights(5, :), 'Name', 'Eq5');
rule5 = "If Fm is S5 then Y is Eq5";

fis = addRule(fis, [rule1; rule2; rule3; rule4; rule5]);

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
    y = zeros(it, 1);
    y(1) = y0;
    y(2) = clip(evalfis(fis, [u(2), u(1), y(1), y(1)]), 0, 99);
    for i = 3:it
        y(i) = clip(evalfis(fis, [u(i), u(i-1), y(i-1), y(i-2)]), 0, 99);
    end
end

u_val = [];
for j=0:0.1:1.3
    u_val = [u_val, j*ones(1, 1000)];
end
y_val = helicrane_it(u_val, length(u_val), [0, 0], [0, 0]);
y_fuzzy_val = helicrane_ts_it(u_val, length(u_val), 0, fis);

point_space = linspace(min(u_val), max(u_val), length(u_val));

figure;
%plot(u_val); hold on;
scatter(point_space, y_val(1, :)', '.', 'r'); hold on;
scatter(point_space, y_fuzzy_val, '.', 'b');
grid on;
legend();

figure;
plot(y_val(1, :)' - y_fuzzy_val);
grid on;
legend();
title("Error of the fuzzy modelization")

%% Testing with noise 

u_val = u_val + 0.1*rand(size(u_val)); %adding noise

y_val = helicrane_it(u_val, length(u_val), [0, 0], [0, 0]);
y_fuzzy_val = helicrane_ts_it(u_val, length(u_val), 0, fis);

[Xs_test, Xi_test, Ai_test, Ts_test] = preparets(narxNet, num2cell(u_val), {}, num2cell(y_val(1, :)));

% Simulate the network on test data
y_test_pred = narxNet(Xs_test, Xi_test, Ai_test);

% Convert cell arrays to numeric arrays for evaluation
y_test_pred = cell2mat(y_test_pred);

point_space = linspace(min(u_val), max(u_val), length(u_val));

figure;
%plot(u_val); hold on;
scatter(point_space, y_val(1, :)', '.', 'r'); hold on;
scatter(point_space, y_fuzzy_val, '.', 'b');
scatter(point_space(1:length(y_test_pred)), y_test_pred, '.', 'g');
grid on;
legend();
