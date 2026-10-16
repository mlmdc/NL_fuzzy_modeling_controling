% Define the fuzzy rules
gain = 90;
gain2 = 1.008;
fis = addMF(fis, 'Y', 'linear', [0.009*gain    -0.0009*gain 0.9988*gain2 -0.0014*gain2  0], 'Name', 'Eq1');
rule1 = "If Fm is S1 then Y is Eq1";

fis = addMF(fis, 'Y', 'linear', [0.0028*gain    -0.0027*gain     0.9987*gain2    -0.0014*gain2  0], 'Name', 'Eq2');
rule2 = "If Fm is S2 then Y is Eq2";

fis = addMF(fis, 'Y', 'linear', [0.0188 *gain   -0.0186 *gain    0.9888*gain2    -0.0117*gain2  0], 'Name', 'Eq3');
rule3 = "If Fm is S3 then Y is Eq3";

fis = addMF(fis, 'Y', 'linear', [0.0188*gain    -0.0186*gain     0.9888*gain2    -0.0117*gain2  0], 'Name', 'Eq4');
rule4 = "If Fm is S4 then Y is Eq4";

fis = addMF(fis, 'Y', 'linear', [0.0492*gain    -0.0491*gain     0.9729*gain2    -0.0329*gain2  0], 'Name', 'Eq5');
rule5 = "If Fm is S5 then Y is Eq5";

fis = addRule(fis, [rule1; rule2; rule3; rule4; rule5]);
