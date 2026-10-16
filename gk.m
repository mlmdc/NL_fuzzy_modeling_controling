clear; close all; clc;

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
load("ident_data.mat");
% Generate synthetic data
X = hz3;

% Parameters
c = 5; % number of clusters
m = 2.0; % fuzziness
epsilon = 1e-5; % convergence threshold
rmax = 100; % max iterations

[U, centers, covariances] = gustafson_kessel(X, c, m, epsilon, rmax);

% gaussian membership
gauss_mf = zeros;

% visualising
[~, labels] = max(U, [], 2);
gscatter(X(:,1), X(:,2), labels);
hold on;
plot(centers(:,1), centers(:,2), 'kx', 'MarkerSize', 15, 'LineWidth', 2);
title('Gustafson-Kessel Clustering');

figure;
hold on;
legend();
for i=1:5
    plot(U(:, i));
    legend(num2str(i));
end
grid on;

figure;
hold on;
legend();
[~, repart] = max(U, [], 2);
models = [];
for i=1:5
    % Weighted mean (center c)
    x_dim = hz3(:, 1);
    u_j = U(:, i);

    % Estimate center (c): weighted mean
    c_jd = sum(u_j .* x_dim) / sum(u_j);

    % Estimate width (a): weighted standard deviation
    sigma_jd = sqrt(sum(u_j .* (x_dim - c_jd).^2) / sum(u_j));
    %sigma_jd = (sum(repart == i)*0.01 + sigma_jd)/2;

    % a is similar to sigma, b is commonly fixed (or you can tune it)
    a_jd = sigma_jd;
    b_jd = 2;  % You can also try tuning this value

    params = [a_jd, centers(i, 1)];
    gauss_mf = gaussmf(hz3(:, 1), params);
    plot(hz3(:, 1), gauss_mf);
    
    W = diag(gauss_mf(3:end-1)); % Sparse matrix because overflow otherwise
    m = 2;
    N = length(hz3(:, 1));
    X = [hz3(1:N-3, 1), hz3(2:N-m, 1), hz3(3:N-1, 1), -hz3(1:N-3, 2), -hz3(2:N-2, 2), ones(size(hz3(1:N-3, 1)))];
    
    % Perform LS
    theta_hat = pinv(X'*W*X)*X'*W*hz3(m+1:end-1, 2);
    
    % discrete-time TF
    model_weights(:,i) = theta_hat;
    
end
grid on;
