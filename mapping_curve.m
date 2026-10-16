% 
clc; close all;


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

function psi = computePsi2(u, y, n_order, delay)
    Nsys = length(u);
    psi = [];
    for j = 1:(n_order+1) %U Fetching
        psi = [psi, u(j + delay: Nsys + j - n_order - delay -1)'];
    end
    for i = 1:n_order %Y fetching
        psi = [psi, y(i+ delay : Nsys + i - 1 - n_order - delay)];
    end
    
end

function [psi, output] = generate_data_set(Fm, n)
    % Fm ~ [lower bound, higher bound];
    sp = n;
    
    input = [(Fm(1)+1e-6)*ones(1, 1000), ...
    Fm(2)*prbs(14)', ...
    (Fm(2)/2)*ones(1, 1000), ...
    (Fm(2)/2)*(1 + chirp(0:0.01:100, 0, 99, 5))];
    
    output = helicrane_it(input, length(input), [0, 0], [0, 0]);
    
    psi = computePsi2(input(sp:end), output(sp:end)', 2, 0);
    output = output(1, sp+2:end)';% - min(output, [], 'all'))';
end

[Umapping, Ymapping] = generate_data_set([0.0, 0.7], 1500);

figure;
plot(Umapping(:, 1)); hold on;
plot(Umapping(:, 2));
grid on;
title("Umapping")
legend();


function params = nLSE(X, Y, alpha)
    % θ̂ = (X^T.X + αI)^-1 . X^T . y
    [n, m] = size(X);
    params = inv(X' * X + alpha*eye(m))*X' * Y;    
end

function res = RLS(A,b,num,len)
%num is the number of identification parameters, that is, the number of columns of A
%len is the length of the data, that is, the number of rows of A
%Solve for Ax=b
%res is the identified parameter, that is, the x value obtained by the solution
%format long;
x = rand(num,1);
I = eye(num, num);
P = (10^6) * I;

for k = 1:len
    Ak = A(k,:); %The new data row, namely phi
    Q1 = P*(Ak'); %The numerator of K(k)
    Q2 = 1 + Ak * P * (Ak'); %K(k)Denominator
    K = Q1/Q2;   %Update K(k) 
    x = x + K * (b(k) - Ak*x);  %Update the identified parameters
    P = (I - K*Ak)*P;    %Update P
    thetae(:,k) = x;   %Record the identification parameters of each calculation
    steps(k) = k;     %Record the current number of steps (can also be understood as the number of data currently used)
end
steps = steps';
res=thetae(:,end);
figure;
grid on;
for i = 1:num
    subplot(num,1,i)
    plot(steps, thetae(i,:));
end
end


[nX, mX] = size(Umapping);
test_params = nLSE(Umapping, Ymapping, 1e-3);
%test_params = RLS(Umapping, Ymapping, mX, nX);
disp(['   X   ']);
disp(test_params');

Ymodel = Umapping*test_params;

figure;
%plot(Ymapping - Umapping*test_params); hold on;
plot(Ymapping); hold on;
plot(Ymodel);
grid on;
legend();

G_fuzzy = fft(Ymodel)./fft(Umapping(:, 1));
G_heli = fft(Ymapping)./fft(Umapping(:, 1));
F = 1/(length(Umapping) * 0.01) * (1:length(Umapping))';


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



figure;
plot(Ymapping - Ymodel); hold on;
%plot(Umapping*test_params);
grid on;
legend();