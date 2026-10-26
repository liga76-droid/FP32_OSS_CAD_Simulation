FP32 FMA v0.3 — linear4 — integrazione Z (milestone)
====================================================

Questa cartella parte dal pacchetto linear4_scheduler e aggiunge un confine RTL di
integrazione fra il prodotto esatto dei significandi e il sideband FP32 di A, B e Z.

Nuovo modulo:
  rtl/fp32_fma_z_pipeline.sv

Nuovo test:
  tb/tb_fma_z_pipeline.sv

Il wrapper riusa fp32_sigmul_linear4 (quattro moltiplicatori 16x16 nel prodotto
24x24) e mantiene allineati al risultato: ID, prodotto, segno del prodotto, esponenti,
operandi originali e classificazione zero/subnormale/normale/infinito/NaN.

NUOVO: exact_sum_scaled rappresenta l'esatto valore algebrico A*B+Z per operandi
finiti come intero signed a 560 bit con quantum fisso 2^-298. Il calcolo usa il prodotto
48-bit, il segno di A*B e il segno di Z; somma magnitudini se i segni coincidono e
sottrae algebricamente quando differiscono. La scala comune conserva tutti i bit dei
binary32 finiti, inclusi subnormali, prima di qualsiasi rounding.

IMPORTANTE — LIMITI DELLA MILESTONE
-----------------------------------
Questo non è ancora una FMA IEEE-754 completa. La somma algebrica esatta è un
reference datapath volutamente molto largo, non una realizzazione ottimizzata per area,
timing o PPA. Il modulo NON esegue ancora:
- normalizzazione del risultato a significando binary32;
- generazione/propagazione GRS e rounding IEEE-754;
- gestione completa di overflow, underflow, inexact, invalid, NaN payload, Inf*0,
  Inf + (-Inf), zero con segni e tutte le combinazioni subnormali.

La scala comune è 2^-298: il valore esatto è exact_sum_scaled * 2^-298.
Per input finiti, exp_unbiased=-126 insieme al significando senza hidden bit rappresenta
correttamente anche i subnormali nella formula valore = significando * 2^(e-23).
Non sono implementati il risultato binary32 arrotondato, overflow/underflow/inexact,
NaN payload, Inf*0, Inf + (-Inf), né tutte le regole IEEE per gli zeri con segno.
Per operandi speciali exact_sum_scaled non va interpretato come risultato IEEE valido;
consultare finite_operands.

La schedule letterale delle nove parziali rimane una reference funzionale separata;
non è ancora mappata sulle finestre fisiche 16x16. Inoltre lo script Yosys in questa
versione seleziona esplicitamente fp32_fma_z_pipeline come top, a differenza del log
precedente che rimuoveva partial_product_scheduler come modulo inutilizzato.

Esecuzione su Windows con OSS CAD Suite:
  run_iverilog_all.bat
  run_yosys_check.bat

Criterio del test FMA: oltre a prodotto, ID e Z, verifica tre casi diretti della somma
algebrica esatta A*B+Z alla scala 2^-298. Non prova ancora tutti i casi finiti, random,
backpressure, normalizzazione/rounding o la conformità IEEE-754 completa.

Non dichiarare PASS prima di aver eseguito localmente gli script. In questa sessione
non è disponibile un eseguibile Icarus/Yosys, quindi il pacchetto non è stato eseguito
qui.

## Nuovo test stress: datapath compatto A*B+Z

Il nuovo DUT `fp32_fma_finite_opt` sostituisce l'uscita fissa a 560 bit con una rappresentazione esatta a esponente dinamico:

`valore = sum_mantissa * 2^sum_exp2`

L'accumulatore è largo 64 bit. I due significandi vengono traslati rispetto al minore esponente binario dei termini e sommati con segno. Per evitare troncamenti, il DUT dichiara `range_supported=1` soltanto quando entrambi gli shift sono <=14 e gli operandi sono finiti. Il testbench genera 512 casi con le scale di prodotto e Z coincidenti, segni e frazioni casuali, casi di carry/cancellazione e backpressure casuale; confronta il risultato contro una reference indipendente a scala fissa da 560 bit esclusivamente nel testbench.

Comandi aggiuntivi:
- `run_iverilog_all.bat` / `run_iverilog_all.sh`: include `tb_fma_finite_opt`.
- `run_yosys_opt_check.bat` / `run_yosys_opt_check.sh`: sintetizza `fp32_fma_finite_opt` come top e verifica quattro `$mul` 16x16, porta somma a 64 bit e assenza dell'uscita 560-bit.

**Limiti dichiarati:** questo DUT è una prova di datapath compatto per un dominio di esponenti controllato, non una FMA IEEE-754 completa. Non esegue normalizzazione binary32, rounding RNE/GRS, overflow/underflow/inexact, né semantica NaN/Inf/zero IEEE. Casi con differenza di scala oltre 14 sono marcati `range_supported=0` e non vanno interpretati come risultati esatti. Il test non dimostra ancora la mappatura fisica letterale della schedule nove parziali sui quattro ALU 16x16, né PPA o II=1 sotto ogni condizione di stallo.

**Verifica in questa sessione:** non è stato possibile eseguire Icarus/Yosys localmente; il pacchetto va compilato e lanciato nell'ambiente OSS CAD Suite dell'utente. Non considerare PASS finché i log locali non lo confermano.


MILESTONE: fp32_fma_ieee (binary32 result path)
================================================
Nuovo modulo RTL: rtl/fp32_fma_ieee.sv. Mantiene la pipeline di prodotto a quattro moltiplicatori 16x16 già presente e aggiunge un accumulatore signed esatto a 560 bit alla scala 2^-298, normalizzazione binary32 e rounding round-to-nearest, ties-to-even tramite guard/round/sticky. Sono esposti i flag NV, DZ, OF, UF, NX come cinque output separati. La division-by-zero è sempre 0 per FMA. Include trattamento di NaN quiet/signaling, infinito, 0*infinito, somma di infiniti opposti, zero e segno dello zero in cancellazione secondo RNE.

IMPORTANTE: questa implementazione è un DUT di riferimento funzionale, NON un datapath PPA-optimized. L'accumulatore a 560 bit e gli shifter variabili sono deliberatamente larghi per preservare l'esattezza dei casi finiti; la sintesi potrebbe essere molto costosa. Il testbench incluso copre casi diretti e speciali, ma non costituisce una dimostrazione completa IEEE-754: serve ancora confronto differenziale massivo con una reference indipendente (idealmente SoftFloat) e test random con backpressure. Non dichiarare conformità completa sulla sola base del test diretto.

La mappatura fisica della schedule letterale delle nove parziali AA..CC resta NON dimostrata: il moltiplicatore integrato continua a usare quattro prodotti parziali 16x16 (HH, HL, LH, LL) e CSA, non la schedule letterale a finestre del documento v0.3. Nessun claim di II=1 universale o PPA è derivato da Yosys.

Esecuzione Windows OSS CAD Suite:
  run_iverilog_all.bat
  run_yosys_ieee_check.bat

Il testbench nuovo stampa PASS solo per i casi diretti codificati. I test non sono stati eseguiti dall'autore del pacchetto in questa sessione; eseguirli localmente e condividere l'intera console.


## Correzione di sintesi Yosys — revisione successiva al crash PROC_MUX

Nel blocco combinazionale di `rtl/fp32_fma_ieee.sv` è stata rimossa la scansione
procedurale dello sticky bit:

  for (i=0; i<560; i=i+1)
    if (i < rshift-2) sticky_bit = sticky_bit | abs_sum[i];

Quella forma generava una grande catena di assegnazioni condizionali/decoder nel
passo `PROC_MUX`. È stata sostituita con uno shift a larghezza fissa seguito da
riduzione OR, mantenendo la definizione sticky = OR(abs_sum[rshift-3:0]) quando
rshift >= 3. La corrispondenza della formula è stata controllata per tutti i valori
di rshift da 0 a 559 con un controllo software, ma questo NON equivale a una
compilazione o sintesi RTL.

Il log `reports/yosys_ieee_run_pre_fix.log` è conservato esclusivamente come
evidenza storica del crash precedente; non rappresenta la versione RTL aggiornata.
Gli artefatti `.vvp` precedenti sono stati rimossi per evitare di confonderli con
simulazioni della versione aggiornata.

**Stato della correzione:** patch sorgente applicata; non verificata con Icarus o
Yosys in questa sessione perché gli eseguibili non sono disponibili. Occorre
rilanciare `run_iverilog_all.bat` e `run_yosys_ieee_check_corrected.bat` (oppure
`run_yosys_ieee_check.bat` dalla directory del progetto) e condividere i log.

Nota sulla revisione successiva:
La versione aggiornata sostituisce la scansione seriale a 560 bit con
rilevamento gerarchico del bit più significativo su 35 gruppi da 16 bit.
La sintesi deve ancora essere verificata localmente.
