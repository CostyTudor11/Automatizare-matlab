# SwEA — automatizare MATLAB pentru TL082

Deschide folderul in MATLAB, deschide **SwEA.m** si apasa Run.
Implicit ruleaza `mod_lucru = "demo"`: fara aparate, cu date sintetice marcate
explicit. Modelul demonstrativ are castig 2 si un pol la 1.5 MHz; aceasta
valoare este aleasa pentru testarea algoritmului, nu reprezinta o masurare
sau o predictie validata pentru TL082.

## Ce modifici

La inceputul `SwEA.m`: `Vin_Vpp`, `f_min`, `f_max`, `puncte_pe_decada`,
rezistentele si factorii sondelor. Setarile initiale sunt 500 mVpp, 1 Hz–5 MHz,
100 intervale logaritmice pe decada, Rf = Rg = 10 kohm si sonde x1.
Grila include exact capetele intervalului si contine 671 de frecvente.

Formulele de castig, faza si prag de taiere sunt declarate cu `syms`.
`matlabFunction` le transforma o singura data in functii numerice. Valorile
trimise aparatelor si calculele din bucla sunt numerice. Astfel, scrierea
ramane simbolica unde este utila, fara substitutii simbolice la fiecare punct.

`semnal` este expus, dar aceasta versiune accepta numai `"SINE"`.
Un raport RMS pentru semnal patrat nu este raspunsul Bode la fundamentala;
selectarea altei forme produce o eroare explicita.

## Fisiere rezultate

Fiecare rulare creeaza un folder distinct in `rezultate_SwEA`:

- `measurements.csv`: frecvente, amplitudini brute si RMS AC, castig,
  intarziere, faza, setari de achizitie si starea fiecarui punct. Se salveaza
  dupa fiecare punct, inclusiv cand masurarea este marcata invalida.
- `cutoff.csv`: **doar `Cutoff_Hz` si `Status`**. Fara Av0, GBW sau frecventa 0 dB.
- `bode.png`: un singur grafic final, frecventa logaritmica, castig in dB
  pe axa stanga si faza in grade pe axa dreapta.
- `bode.fig`, fisiere MAT/JSON si jurnalul comenzilor: pentru redeschidere
  si diagnostic. Nu se salveaza capturi PNG la fiecare frecventa.

La eroare, CSV-ul cu punctele deja masurate ramane salvat, impreuna cu
rezultatele partiale si mesajul erorii. Graficul final se creeaza numai dupa
terminarea baleiajului. Generatorul este oprit la final sau la iesirea cu eroare.

## Metoda

1. Calculatorul identifica generatorul SDG1032X si osciloscopul SDS824X HD
   prin VISA USB si verifica identitatea lor. Generatorul este configurat
   sinus, offset zero, amplitudine Vpp si afisare pentru sarcina High-Z.
2. CH1 masoara intrarea, CH2 iesirea; cuplaj DC, fara inversare, fara limitare
   de banda. Pragurile masurarilor sunt 90/50/10%. Trigger: CH1, front crescator.
3. La fiecare frecventa, timpul de stabilizare si baza de timp depind de
   perioada. Se solicita o achizitie SINGLE noua si se asteapta oprirea ei.
   Sunt verificate durata capturii si densitatea esantioanelor. Scalele se
   adapteaza numai cand este necesar; se permit maximum trei incercari.
4. Se citesc Vpp, RMS pe un ciclu, media acelui ciclu, frecventa CH1 si
   intarzierea fronturilor crescatoare CH1→CH2 (FRFR in interfata, `FRR` SCPI).
   `V_AC = sqrt(V_CRMS^2 - V_CMean^2)`, `G = Vout_AC/Vin_AC`.
   Amplitudinea reala de intrare este masurata; nu se presupune egala cu
   setarea generatorului si nu se foloseste o bucla de reglare a acesteia.
5. Faza este `-360*f_masurata*intarziere`, adusa in intervalul [-180,180).
   Frontul de iesire urmator poate introduce o perioada intreaga, eliminata
   prin aceasta normalizare. Metoda este destinata sinusurilor curate.
6. Referinta pentru taiere este mediana castigului masurat intre 10 si
   1000 Hz, nu valoarea teoretica 6.02 dB. Banda este modificabila prin
   `cfg.plateauBandHz`. Se cer minimum 10 puncte, minimum 80% puncte valide,
   aproximativ o decada acoperita si abatere maxima 0.25 dB de la mediana.
7. Pragul este referinta minus `10*log10(2)` (aproximativ 3.0103 dB).
   Interpolarea se face intre puncte vecine valide, in dB fata de log10(f).
   Lipsa platoului, lipsa intersectiei, date invalide langa intersectie sau
   intersectii multiple produc `NaN` si un motiv explicit, fara extrapolare.

Frecventa de taiere este a **montajului in bucla inchisa**, inclusiv efectele
sondei si breadboardului. Nu este caracteristica in bucla deschisa din datasheet.
Verificarea Vpp/RMS poate semnala deformare/zgomot, dar nu este o masurare THD.
Punctele suspecte sunt pastrate brut, cu castig/faza invalidata unde este cazul.
Nu se aplica netezire care sa ascunda masuratorile problematice.

## Cand ai bancul pregatit

Ai nevoie de MATLAB, **Symbolic Math Toolbox** pentru `syms`, Instrument
Control Toolbox pentru USB si o implementare VISA compatibila instalata
(de exemplu NI-VISA). Un simplu cablu USB nu inlocuieste driverul VISA.

Conecteaza separat fiecare aparat la calculator prin portul USB Device.
Generator CH1 → intrarea neinversoare; osciloscop CH1 → aceeasi intrare;
osciloscop CH2 → iesire. Rf = 10 kohm intre iesire si intrarea inversoare,
Rg = 10 kohm intre intrarea inversoare si masa. Alimentarea ±10 V se seteaza
manual; scriptul nu controleaza sursa. Leaga masele generatorului si sondelor
la masa comuna de 0 V, nu la alimentarea -10 V. Foloseste decuplare locala
a alimentarilor si conexiuni scurte.

Factorii `sonde` trebuie sa corespunda comutatoarelor fizice. Banda si
capacitatea sondelor in x1, precum si parazitii breadboardului, trebuie
verificate inainte de a interpreta rezultatele pana la 5 MHz. Codul nu
poate compensa automat aceste efecte. Un test cu ambele sonde pe acelasi
sinus trebuie sa dea aproximativ 0 dB si 0 grade; un circuit RC cunoscut
permite verificarea semnului fazei. Aceste verificari nu sunt simulate de cod.

Ruleaza `visadevlist` pentru a verifica detectia. Daca sunt mai multe aparate
identice sau identificarea automata nu reuseste, copiaza `ResourceName` in
`cfg.generatorResource` / `cfg.scopeResource` din SwEA.m.
Schimba `mod_lucru` in `"usb"` pentru masurarea reala.
Pentru prima verificare rapida poti adauga inainte de `run_swea`:

```matlab
cfg.frequencyOverride = [10 1000 100000];
```

Acest test scurt nu determina taierea. Sterge linia pentru baleiajul complet.
Pentru alt opamp pastreaza metoda daca montajul ramane neinversor si raspunsul
are un platou urmat de o taiere superioara; adapteaza amplitudinea, frecventele
si, daca este necesar, banda de referinta si timpul de stabilizare.

## Verificari si limite de validare

`test_swea` verifica in MATLAB grila, eliminarea offsetului DC, faza,
interpolarea taierii, cazurile invalide si fisierele produse in modul DEMO.
Nu necesita aparate si foloseste formulele numerice echivalente.

Livrarea a fost verificata cu analizorul static MATLAB MISS_HIT si prin
verificari numerice independente. MATLAB si aparatele nu au fost disponibile
in mediul de lucru: executia efectiva a scriptului si a `test_swea`, raspunsurile
SCPI, sincronizarea achizitiei si precizia pe banc raman de validat.
Nu este prezentata ca o automatizare deja testata pe hardware.

## Documentatie folosita

- SIGLENT [SDS Series Programming Guide](https://siglentna.com/download/42429/),
  EN11G: model/firmware p.18; achizitie pp.36–47; canale pp.50–58;
  masurari pp.336–347; praguri pp.369–372; trigger pp.482–495.
  Profilul implementat cere firmware SDS800X HD minimum 1.1.3.1.
- SIGLENT [SDS800X HD User Manual](https://siglentna.com/download/42435/),
  definitiile masurarilor pe ciclu si intarzierii FRFR, pp.120–125.
- SIGLENT [SDG Series Programming Guide](https://siglentna.com/download/16164/):
  OUTP, BSWV, MDWV, SWWV si BTWV.
- MathWorks: [syms](https://www.mathworks.com/help/symbolic/syms.html),
  [matlabFunction](https://www.mathworks.com/help/symbolic/sym.matlabfunction.html),
  [visadev](https://www.mathworks.com/help/instrument/visadev.html).

Lucrarea mentionata anterior nu a fost disponibila in fisierele accesibile
acestei livrari; nu pretind ca acest cod a fost verificat fata de ea.
