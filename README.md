# SwEA — Caracterizarea automată a unui amplificator cu TL082

Am realizat acest proiect pentru a măsura automat răspunsul în frecvență al unui amplificator neinversor cu TL082.

Am folosit MATLAB pentru controlul prin USB al unui generator de semnal și al unui osciloscop. Programul măsoară tensiunile de intrare și de ieșire, calculează câștigul și faza și generează graficul Bode.

Măsurarea principală acoperă intervalul **1 Hz–5 MHz**, cu **671 de puncte**. Frecvența de tăiere obținută în această rulare este de aproximativ **2,3224 MHz**.

## Obiectivul proiectului

Am urmărit automatizarea etapelor necesare caracterizării unui amplificator:

- configurarea generatorului și a osciloscopului;
- modificarea frecvenței semnalului;
- achiziția tensiunilor de intrare și de ieșire;
- calculul câștigului și al fazei;
- salvarea măsurătorilor;
- determinarea frecvenței de tăiere;
- reprezentarea grafică a rezultatelor.

Am măsurat răspunsul în buclă închisă al montajului real, cu sondele conectate. Nu am măsurat direct câștigul în buclă deschisă sau GBW-ul intern al TL082.

## Montajul experimental

Am realizat pe breadboard un amplificator neinversor, cu următoarea configurație:

| Parametru | Valoare |
|---|---|
| Amplificator operațional | TL082 |
| Alimentare | ±10 V |
| Rezistență de reacție Rf | 10 kΩ |
| Rezistență către masă Rg | 10 kΩ |
| Câștig nominal | 2 V/V ≈ 6,02 dB |
| Semnal de intrare | Sinusoidal |
| Amplitudine setată pe generator | 500 mVpp |
| Offset | 0 V |
| Interval principal | 1 Hz–5 MHz |
| Densitatea baleiajului | 100 de pași pe decadă |
| Sonde | ×1 pe ambele canale |
| Cuplajul canalelor | DC |
| Sarcină externă | Sonda osciloscopului |

Câștigul nominal al montajului este:

```text
G = 1 + Rf/Rg = 2
```

Rețeaua de reacție încarcă și ea ieșirea amplificatorului.

### Echipamente folosite

- generator SIGLENT SDG1032X;
- osciloscop SIGLENT SDS824X HD;
- sursă de alimentare pentru ±10 V;
- laptop cu MATLAB;
- două cabluri USB;
- breadboard, rezistențe și sonde.

### Conexiuni

| Conexiune | Destinație |
|---|---|
| Generator CH1 | Intrarea neinversoare a amplificatorului |
| Osciloscop CH1 | Intrarea amplificatorului |
| Osciloscop CH2 | Ieșirea amplificatorului |
| Rf | Între ieșire și intrarea inversoare |
| Rg | Între intrarea inversoare și masa circuitului |
| Masele generatorului și sondelor | Masa comună de 0 V |
| USB Device generator | Laptop |
| USB Device osciloscop | Laptop |

Masele sondelor sunt conectate la **0 V**, nu la −10 V.

Alimentarea este configurată manual. Scriptul controlează generatorul și osciloscopul, nu sursa de alimentare.

## Mediul software

Am folosit:

- Windows 11;
- MATLAB R2026b;
- Instrument Control Toolbox;
- Symbolic Math Toolbox;
- NI-VISA.

Instrument Control Toolbox asigură comunicația cu aparatele. Symbolic Math Toolbox este folosit pentru declararea formulelor cu `syms` în scriptul principal.

Am verificat detectarea aparatelor în NI MAX și apoi în MATLAB:

```matlab
devices = visadevlist;
disp(devices)
```

Firmware-urile raportate de instrumentele folosite au fost:

| Aparat | Firmware |
|---|---|
| SDG1032X | `1.01.01.33R8` |
| SDS824X HD | `4.8.12.1.1.6.5` |

Compatibilitatea cu alte modele sau versiuni de firmware nu a fost verificată.

## Structura programului

Am separat parametrii de utilizare, comunicația cu aparatele și calculele în mai multe fișiere.

| Fișier | Rol |
|---|---|
| `SwEA.m` | Script principal, parametri și formule simbolice |
| `swea_config.m` | Configurație implicită, toleranțe și timpi |
| `run_swea.m` | Controlul aparatelor, achiziție și salvare |
| `swea_frequencies.m` | Construirea grilei de frecvențe |
| `swea_reduce.m` | Calculul câștigului și al fazei; verificarea datelor |
| `swea_cutoff.m` | Determinarea frecvenței de tăiere |
| `swea_numeric_formulas.m` | Formule numerice pentru apeluri directe și teste |
| `test_swea.m` | Teste fără aparate |

Toate fișierele MATLAB sunt păstrate în același director.

## Modurile de funcționare

### DEMO

Modul `demo` generează date sintetice și permite verificarea calculelor și a salvării fără conectarea aparatelor.

```matlab
mod_lucru = "demo";
```

Modelul demonstrativ are câștigul 2 și un pol la 1,5 MHz. Nu reprezintă o măsurare a circuitului și nici un model complet al montajului cu TL082.

Folderele demonstrative sunt identificate prin prefixul `DEMO_SYNTHETIC`, iar stările punctelor prin prefixul `SYNTHETIC_`.

### USB

Modul `usb` folosește instrumentele conectate și măsoară circuitul real.

```matlab
mod_lucru = "usb";
```

Programul identifică automat instrumentele după model atunci când adresele sunt lăsate necompletate:

```matlab
cfg.generatorResource = "";
cfg.scopeResource = "";
```

Pentru configurații cu mai multe aparate de același tip, adresele pot fi completate explicit cu valorile `ResourceName` returnate de `visadevlist`.

## Verificările realizate înaintea baleiajului complet

Am verificat mai întâi calculele și generarea fișierelor folosind:

```matlab
test_swea
```

Testele includ:

- grila logaritmică de frecvențe;
- calculul câștigului în prezența unui offset;
- calculul fazei;
- detectarea unor date invalide;
- determinarea tăierii pentru modelul demonstrativ;
- generarea celor două CSV-uri și a graficului PNG.

Rezultatele temporare ale testului sunt șterse automat la ieșire. Testele nu validează comunicația USB.

După conectarea instrumentelor, am efectuat o probă reală la **100 Hz, 1 kHz și 10 kHz**. Aceasta a permis verificarea comunicației, a amplitudinilor și a opririi generatorului la final.

## Rularea măsurării

Parametrii principali sunt modificați în `SwEA.m`.

Pentru măsurarea documentată am folosit:

```matlab
mod_lucru = "usb";
Vin_Vpp = 0.500;

f_min = 1;
f_max = 5e6;
puncte_pe_decada = 100;

semnal = "SINE";
R_feedback = 10e3;
R_masa = 10e3;
sonde = [1 1];
```

Selecția unei liste speciale de frecvențe este dezactivată prin:

```matlab
cfg.frequencyOverride = [];
```

Măsurarea este pornită prin rularea scriptului `SwEA.m`. Scriptul reconstruiește configurația folosind parametrii declarați în el.

În timpul baleiajului, programul:

1. setează frecvența generatorului;
2. ajustează baza de timp;
3. așteaptă stabilizarea;
4. configurează scalele verticale;
5. execută o achiziție SINGLE;
6. verifică finalizarea achiziției;
7. citește și verifică măsurătorile;
8. salvează punctul în CSV.

La frecvențe joase, achiziția durează mai mult. De exemplu, la 1 Hz, cinci perioade ocupă cinci secunde, înainte de timpul suplimentar de stabilizare și comunicație.

Programul încearcă oprirea generatorului la final și la ieșirea din funcție. Starea ieșirii trebuie verificată și după o întrerupere manuală.

Punctele deja scrise în CSV rămân disponibile. Reluarea automată a unei măsurări întrerupte nu este implementată.

## Calculul câștigului și al fazei

Am folosit valorile RMS măsurate pe ciclu și componenta continuă pentru estimarea componentei alternative:

```text
V_AC_RMS = sqrt(V_CRMS^2 - V_CMean^2)
```

Câștigul este calculat din raportul tensiunilor efectiv măsurate:

```text
G = Vout_AC_RMS / Vin_AC_RMS
G_dB = 20 * log10(G)
```

Valoarea nominală setată pe generator nu este folosită în locul tensiunii de intrare măsurate.

Valorile Vpp sunt păstrate pentru verificări. Scriptul nu ajustează repetat amplitudinea generatorului pentru a menține exact 500 mVpp la intrarea montajului.

Convenția pentru fază este:

```text
faza = faza_iesire - faza_intrare
```

Calculul pornește de la întârzierea dintre fronturile crescătoare:

```text
faza_grade = -360 * frecventa * intarziere
```

Normalizarea este realizată în funcția de prelucrare. Validarea experimentală a semnului fazei cu o întârziere cunoscută nu a fost documentată în acest proiect.

## Determinarea frecvenței de tăiere

Frecvența de tăiere este determinată la o scădere de **3,0103 dB față de platoul măsurat**.

Referința nu este maximul curbei.

Banda configurată pentru estimarea platoului este **10–1000 Hz**. În rulările începute la 100 Hz sunt disponibile numai punctele din intervalul 100–1000 Hz.

Trecerea pragului este interpolată în dB față de logaritmul frecvenței. Dacă datele nu permit determinarea tăierii, rezultatul este `NaN`, însoțit de o stare explicativă.

## Fișierele rezultate

Fiecare rulare generează un director separat în `rezultate_SwEA`.

| Fișier | Conținut |
|---|---|
| `measurements.csv` | Măsurătorile și starea fiecărui punct |
| `cutoff.csv` | Frecvența de tăiere și starea calculului |
| `bode.png` | Graficul final |
| `bode.fig` | Figura editabilă în MATLAB |
| `config.json`, `config.mat` | Configurația folosită |
| `results.mat` | Tabelul rezultatelor și configurația |
| `instrument_log.txt` | Jurnalul comenzilor și răspunsurilor |
| `completed.txt` | Modul, numărul de puncte și durata |
| `partial_results.mat`, `FAILED.txt` | Date parțiale și eroarea, dacă aceasta este capturată |

În grafic, câștigul este reprezentat cu **roșu**, iar faza cu **albastru**. Frecvența este reprezentată pe scară logaritmică.

Pentru citirea CSV-urilor folosesc explicit separatorul virgulă:

```matlab
folder = 'calea folderului cu rezultate';

t = readtable(fullfile(folder,'measurements.csv'),'Delimiter',',');
c = readtable(fullfile(folder,'cutoff.csv'),'Delimiter',',');

disp(c)

suspect = string(t.Status) ~= "OK";

disp(t(suspect, ...
    {'FrequencySet_Hz','Gain_dB','Phase_deg','Status'}))
```

## Interpretarea stărilor

| Stare | Semnificație |
|---|---|
| `OK` | Punctul a trecut verificările implementate |
| `SYNTHETIC_OK` | Punct generat în modul demonstrativ |
| `INPUT_NOT_AT_TARGET` | Amplitudinea de intrare se abate de la țintă |
| `CHECK_WAVEFORM_OR_NOISE` | Verificarea Vpp/RMS nu a trecut |
| `FREQUENCY_MISMATCH` | Frecvența măsurată depășește toleranța față de cea cerută |
| `SCREEN_RANGE_SUSPECT` | Încadrarea verticală este suspectă |
| `OK_WITH_INVALID_POINTS_ELSEWHERE` | Tăiere determinată, cu puncte invalide în alte zone |

Stările se pot combina. Abaterea amplitudinii de intrare nu invalidează automat raportul tensiunilor măsurate.

Punctele invalidate au valori `NaN` și apar ca întreruperi în grafic.

## Rezultatul principal: 1 Hz–5 MHz

Pentru documentarea proiectului am ales rularea completă realizată la **18 octombrie 2026**.

| Parametru | Rezultat |
|---|---|
| Interval | 1 Hz–5 MHz |
| Număr de puncte | 671 |
| Câștig în bandă | Aproximativ 5,95–5,98 dB |
| Frecvență de tăiere | **2,3224 MHz** |
| Stare tăiere | `OK_WITH_INVALID_POINTS_ELSEWHERE` |
| Maxim observat | Aproximativ 8,05 dB în zona 1,26–1,29 MHz |
| Punct invalid | Aproximativ 3,7154 MHz |
| Stare punct invalid | `INPUT_NOT_AT_TARGET|CHECK_WAVEFORM_OR_NOISE` |

Am observat o creștere a câștigului înainte de cădere. Nu am izolat experimental cauza acestui maxim și nu îl interpretez ca dovadă suficientă a unei oscilații.

### Comparația cu rulările suplimentare

| Rulare | Interval | Frecvență de tăiere |
|---|---|---|
| Prima | 100 Hz–5 MHz | 2,543 MHz |
| Principală | 1 Hz–5 MHz | 2,3224 MHz |
| Repetare | 100 Hz–5 MHz | 2,4271 MHz |

Cele două rulări cu același interval diferă cu aproximativ **4,6%**, raportat la prima.

Nu am stabilit cauza acestei variații. Am păstrat rezultatele suplimentare separat, pentru comparație, fără să le combin cu măsurarea principală.

## Limite și observații

- Rezultatele includ influența breadboardului, a conexiunilor și a sondelor.
- Modelul și banda sondelor în poziția ×1 nu au fost documentate.
- Nu am realizat o calibrare completă între canalele de măsurare.
- Validarea experimentală a semnului fazei rămâne de făcut.
- Nu am realizat un buget formal de incertitudine.
- Starea `OK` confirmă verificările software, nu precizia absolută.
- La frecvențe mari au apărut avertizări de amplitudine și puncte invalidate.
- Modelul DEMO nu reproduce toate caracteristicile montajului real.

## Probleme întâlnite și rezolvări

### Detectarea aparatelor

Inițial, aparatele nu erau detectate de `visadevlist`. După instalarea NI-VISA, detectarea a fost confirmată în NI MAX și în MATLAB.

### Închiderea conexiunilor

Prima versiune a produs o avertizare `onCleanup` legată de variabila `gen`. Am modificat mecanismul de oprire pentru a transmite explicit obiectele instrumentelor către funcția de curățare.

### Durata la frecvențe joase

Baleiajul început la 1 Hz este lent în prima parte din cauza duratei perioadelor, a stabilizării și a achiziției. Pentru verificări intermediare am folosit intervalul 100 Hz–5 MHz.

### Citirea CSV-urilor

Detectarea automată a separatorului a interpretat greșit un fișier. Am folosit explicit:

```matlab
'Delimiter', ','
```

## Concluzie

Am realizat și utilizat un sistem de măsurare automată MATLAB–USB pentru caracterizarea unui amplificator cu TL082.

Programul permite configurarea testului, achiziția datelor, calculul câștigului și al fazei, salvarea rezultatelor și determinarea frecvenței de tăiere.

Pentru rularea principală, între 1 Hz și 5 MHz, am obținut un câștig în bandă apropiat de valoarea nominală de 2 V/V și o frecvență de tăiere de aproximativ **2,3224 MHz**, cu limitele de măsurare prezentate mai sus.